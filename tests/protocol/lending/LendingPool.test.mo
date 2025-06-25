import LendingFactory "../../../src/protocol/lending/LendingFactory";
import LedgerTypes "../../../src/protocol/ledger/Types";
import LendingTypes "../../../src/protocol/lending/Types";
import LedgerFungibleFake "../../fake/LedgerFungibleFake";
import LedgerAccounting "../../fake/LedgerAccounting";
import Duration "../../../src/protocol/duration/Duration";
import PriceTracker "../../../src/protocol/ledger/PriceTracker";
import ClockMock "../../mocks/ClockMock";
import DexMock "../../mocks/DexMock";
import DexFake "../../fake/DexFake";

import { test; suite; } "mo:test/async";

import Map "mo:map/Map";
import Set "mo:map/Set";
import Fuzz "mo:fuzz";
import Result "mo:base/Result";

import { verify; Testify; } = "../../utils/Testify";

await suite("LendingPool", func(): async() {

    type Account = LedgerTypes.Account;
    type BorrowPosition = LendingTypes.BorrowPosition;
    type SupplyPosition = LendingTypes.SupplyPosition;
    type Withdrawal = LendingTypes.Withdrawal;
    type SupplyRegister = LendingTypes.SupplyRegister;
    type BorrowRegister = LendingTypes.BorrowRegister;
    type SupplyInput = LendingTypes.SupplyInput;

    let fuzz = Fuzz.fromSeed(0);
    let equal_balances = LedgerAccounting.testify_balances.equal;

    let parameters = {
        supply_cap = 1_000_000_000_000; // arbitrary supply cap
        borrow_cap = 1_000_000_000_000; // arbitrary borrow cap
        reserve_liquidity = 0.1;
        lending_fee_ratio = 0.1;
        target_ltv = 0.60;
        max_ltv = 0.70;
        liquidation_threshold = 0.75;
        liquidation_penalty = 0.03;
        close_factor = 0.5;
        max_slippage = 0.05; // Not used in that test, but required by the type
        interest_rate_curve = [
            { utilization = 0.0; rate = 0.02 },
            { utilization = 0.8; rate = 0.20 },
            { utilization = 1.0; rate = 1.00 },
        ];
    };

    await test("Nominal test", func() : async() {

        // === Setup Phase ===

        let clock = ClockMock.ClockMock();
        // Set time to Day 1
        clock.expect_call(#get_time(#returns(Duration.toTime(#DAYS(1)))), #repeatedly);

        let index = { 
            var value = {
                borrow_rate = 0.0;
                supply_rate = 0.0;
                accrued_interests = {
                    fees = 0.0;
                    supply = 0.0;
                };
                borrow_index = {
                    value = 1.0; 
                    timestamp = clock.get_time();
                };
                supply_index = {
                    value = 1.0; 
                    timestamp = clock.get_time();
                };
                timestamp = clock.get_time();  // Day 1
                utilization = {
                    raw_supplied = 0.0;
                    raw_borrowed = 0.0;
                    ratio = 0.0;
                };
            };
        };

        let register = {
            borrow_positions = Map.new<Account, BorrowPosition>();
            supply_positions = Map.new<Text, SupplyPosition>();
            withdrawals = Map.new<Text, Withdrawal>();
            withdraw_queue = Set.new<Text>();
        };

        let admin = fuzz.principal.randomPrincipal(10);
        let protocol = { fuzz.icrc1.randomAccount() with name = "protocol" };
        let lender = { fuzz.icrc1.randomAccount() with name = "lender" };
        let borrower = { fuzz.icrc1.randomAccount() with name = "borrower" };

        let protocol_info = {
            principal = protocol.owner;
            supply = { subaccount = protocol.subaccount; local_balance = { var value = 0; } };
            collateral = { subaccount = protocol.subaccount; local_balance = { var value = 0; } };
        };

        let supply_accounting = LedgerAccounting.LedgerAccounting([(protocol, 0), (lender, 1_000), (borrower, 1_000)]);
        let collateral_accounting = LedgerAccounting.LedgerAccounting([(protocol, 0), (lender, 0), (borrower, 5_000)]);
        let supply_ledger = LedgerFungibleFake.LedgerFungibleFake({account = protocol; ledger_accounting = supply_accounting; fee = 0; token_symbol = ""});
        let collateral_ledger = LedgerFungibleFake.LedgerFungibleFake({account = protocol; ledger_accounting = collateral_accounting; fee = 0; token_symbol = ""});

        let collateral_price_in_supply = { var value = ?1.0; }; // 1:1 price

        let dex = DexMock.DexMock();

        let collateral_price_tracker = PriceTracker.PriceTracker({
            dex;
            tracked_price = collateral_price_in_supply;
            pay_ledger = collateral_ledger;
            receive_ledger = supply_ledger;
        });

        // Build the lending system
        let { indexer; supply_registry; borrow_registry; withdrawal_queue; } = LendingFactory.build({
            admin;
            protocol_info;
            parameters;
            index;
            register;
            supply_ledger;
            collateral_ledger;
            dex;
            collateral_price_tracker;
            clock;
        });

        // === Initial Assertions ===
        
        verify(indexer.get_index().borrow_index.value, 1.0, Testify.float.equalEpsilon9);
        verify(supply_accounting.balances(), [ (protocol, 0), (lender, 1_000), (borrower, 1_000) ], equal_balances);
        verify(collateral_accounting.balances(), [ (protocol, 0), (lender, 0), (borrower, 5_000) ], equal_balances);

        // === Supply Flow ===

        // Lender supplies 1000 tokens — this should increase raw_supplied
        let supply_1_result = await* supply_registry.add_position({
            id = "supply1";
            account = lender;
            supplied = 1000;
        });
        verify(supply_1_result, #ok(1), Testify.result(Testify.nat.equal, Testify.text.equal).equal);

        // Expect raw_supplied to reflect the supply
        verify(indexer.get_index().utilization.raw_supplied, 1000.0, Testify.float.equalEpsilon9);

        // No interest has accrued yet (same timestamp), so indexes should be unchanged
        verify(indexer.get_index().borrow_index.value, 1.0, Testify.float.equalEpsilon9);
        verify(indexer.get_index().supply_index.value, 1.0, Testify.float.equalEpsilon9);

        // Tokens moved into the pool
        verify(supply_accounting.balances(), [ (protocol, 1_000), (lender, 0), (borrower, 1_000) ], equal_balances);

        // === Advance Time to Day 2 ===

        clock.expect_call(#get_time(#returns(Duration.toTime(#DAYS(2)))), #repeatedly);

        // === Collateral Flow ===

        // Borrower supplies 5000 worth of collateral
        let collateral_1_result = await* borrow_registry.run_operation({ account = borrower; kind = #PROVIDE_COLLATERAL({ amount = 5000 }); });
        verify(Result.isOk(collateral_1_result), true, Testify.bool.equal);
        verify(collateral_accounting.balances(), [ (protocol, 5_000), (lender, 0), (borrower, 0) ], equal_balances);

        // === Borrow Flow ===

        // Borrower borrows 200 tokens
        let borrow_1_result = await* borrow_registry.run_operation({ account = borrower; kind = #BORROW_SUPPLY({ amount = 200 }); });
        verify(Result.isOk(borrow_1_result), true, Testify.bool.equal);

        // 200 tokens have left the pool
        verify(supply_accounting.balances(), [ (protocol, 800), (lender, 0), (borrower, 1200) ], equal_balances);

        // === Post-borrow Expectations ===

        // A borrow has occurred, so utilization > 0 → non-zero borrow rate is established
        // But supply interest was calculated *before* the rate was updated (still 0%)
        // So the borrow index has increased slightly due to non-zero rate, but:
        verify(indexer.get_index().borrow_index.value, 1.0, Testify.float.greaterThan);

        // Supply rate became non-zero only after this update — not enough time passed for interest
        // So supply_index is still 1.0 — this is correct behavior!
        verify(indexer.get_index().supply_index.value, 1.0, Testify.float.equalEpsilon9);

        // === Advance Time to Day 100 (interest should accrue) ===
        clock.expect_call(#get_time(#returns(Duration.toTime(#DAYS(100)))), #repeatedly);

        // Trigger an index update by reading state
        let state_day100 = indexer.get_index();

        // Borrow index should have increased more due to time and utilization
        verify(state_day100.borrow_index.value, 1.0, Testify.float.greaterThan);

        // Supply index should now also have increased due to non-zero supply rate
        verify(state_day100.supply_index.value, 1.0, Testify.float.greaterThan);

        // === Borrower Repayment ===

        // Borrower repays FULL amount, got to 201 tokens to account for accrued interest
        let repay_result = await* borrow_registry.run_operation({ account = borrower; kind = #REPAY_SUPPLY({ repayment = #FULL }); });
        verify(Result.isOk(repay_result), true, Testify.bool.equal);

        // Protocol should receive more tokens than it lent out due to interest
        verify(supply_accounting.balances(), [ (protocol, 1_004), (lender, 0), (borrower, 996) ], equal_balances);

        // Utilization should return to 0
        verify(indexer.get_index().utilization.raw_borrowed, 0.0, Testify.float.equalEpsilon9);
        verify(indexer.get_index().utilization.ratio, 0.0, Testify.float.equalEpsilon9);

        // === Lender Withdrawal ===

        let withdraw_result = supply_registry.remove_position({
            id = "supply1";
            share = 1.0; // Full withdrawal
        });
        ignore await* withdrawal_queue.process_pending_withdrawals(); // To effectively withdraw the funds from remove_position

        verify(withdraw_result, #ok(1003), Testify.result(Testify.nat.equal, Testify.text.equal).equal);
        verify(supply_accounting.balances(), [ (protocol, 1), (lender, 1_003), (borrower, 996) ], equal_balances);

        // Final state checks: indexes still increasing, no liquidation, clean balances
        let final_state = indexer.get_index();
        verify(final_state.borrow_index.value, 1.0, Testify.float.greaterThan);
        verify(final_state.supply_index.value, 1.0, Testify.float.greaterThan);

        // Collateral is untouched, since no liquidation
        verify(collateral_accounting.balances(), [ (protocol, 5_000), (lender, 0), (borrower, 0) ], equal_balances);

        // === Collateral Withdrawal ===

        // Borrower withdraw 5000 worth of collateral
        let collateral_withdrawal_result = await* borrow_registry.run_operation({ 
            account = borrower; 
            kind = #WITHDRAW_COLLATERAL({ amount = 5000 });
        });
        verify(Result.isOk(collateral_withdrawal_result), true, Testify.bool.equal);
        verify(collateral_accounting.balances(), [ (protocol, 0), (lender, 0), (borrower, 5_000) ], equal_balances);
    });

    await test("Liquidation on collateral price crash", func() : async() {

        // === Setup Phase (same as nominal) ===

        let clock = ClockMock.ClockMock();
        clock.expect_call(#get_time(#returns(Duration.toTime(#DAYS(1)))), #repeatedly);

        let index = { 
            var value = {
                borrow_rate = 0.0;
                supply_rate = 0.0;
                accrued_interests = {
                    fees = 0.0;
                    supply = 0.0;
                };
                borrow_index = {
                    value = 1.0; 
                    timestamp = clock.get_time();
                };
                supply_index = {
                    value = 1.0; 
                    timestamp = clock.get_time();
                };
                timestamp = clock.get_time();  // Day 1
                utilization = {
                    raw_supplied = 0.0;
                    raw_borrowed = 0.0;
                    ratio = 0.0;
                };
            };
        };

        let register = {
            borrow_positions = Map.new<Account, BorrowPosition>();
            supply_positions = Map.new<Text, SupplyPosition>();
            withdrawals = Map.new<Text, Withdrawal>();
            withdraw_queue = Set.new<Text>();
        };

        let admin = fuzz.principal.randomPrincipal(10);
        let dex = { fuzz.icrc1.randomAccount() with name = "dex" };
        let protocol = { fuzz.icrc1.randomAccount() with name = "protocol" };
        let lender = { fuzz.icrc1.randomAccount() with name = "lender" };
        let borrower = { fuzz.icrc1.randomAccount() with name = "borrower" };

        let protocol_info = {
            principal = protocol.owner;
            supply = { subaccount = protocol.subaccount; local_balance = { var value = 0; } };
            collateral = { subaccount = protocol.subaccount; local_balance = { var value = 0; } };
        };

        let supply_accounting = LedgerAccounting.LedgerAccounting([(dex, 2_000), (protocol, 0), (lender, 10_000), (borrower, 10_000)]);
        let collateral_accounting = LedgerAccounting.LedgerAccounting([(dex, 0), (protocol, 0), (lender, 0), (borrower, 10_000)]);
        let supply_ledger = LedgerFungibleFake.LedgerFungibleFake({account = protocol; ledger_accounting = supply_accounting; fee = 0; token_symbol = ""});
        let collateral_ledger = LedgerFungibleFake.LedgerFungibleFake({account = protocol; ledger_accounting = collateral_accounting; fee = 0; token_symbol = ""});

        let collateral_price_in_supply = { var value = ?1.0; }; // Start with 1:1 price

        let dex_fake = DexFake.DexFake({ 
            account = dex;
            config = {
                pay_accounting = collateral_accounting;
                receive_accounting = supply_accounting;
                pay_token = "";
                receive_token = "";
            };
            price = collateral_price_in_supply;
        });

        let collateral_price_tracker = PriceTracker.PriceTracker({
            dex = dex_fake;
            tracked_price = collateral_price_in_supply;
            pay_ledger = collateral_ledger;
            receive_ledger = supply_ledger;
        });

        // Build the lending system
        let { indexer; supply_registry; borrow_registry; withdrawal_queue; } = LendingFactory.build({
            admin;
            collateral_price_tracker;
            protocol_info;
            parameters;
            index;
            register;
            supply_ledger;
            collateral_ledger;
            dex = dex_fake;
            clock;
        });

        // === Initial Assertions ===
        
        verify(indexer.get_index().borrow_index.value, 1.0, Testify.float.equalEpsilon9);

        // Lender supplies 1000 tokens
        let supply_1_result = await* supply_registry.add_position({
            id = "supply1";
            account = lender;
            supplied = 1000;
        });
        verify(supply_1_result, #ok(1), Testify.result(Testify.nat.equal, Testify.text.equal).equal);
        verify(supply_accounting.balances(), [ (dex, 2_000), (protocol, 1_000), (lender, 9_000), (borrower, 10_000) ], equal_balances);
        
        // Borrower supplies 2000 worth of collateral
        let collateral_1_result = await* borrow_registry.run_operation({ account = borrower; kind = #PROVIDE_COLLATERAL({ amount = 2000 }); });
        verify(Result.isOk(collateral_1_result), true, Testify.bool.equal);
        verify(collateral_accounting.balances(), [ (dex, 0), (protocol, 2_000), (lender, 0), (borrower, 8_000) ], equal_balances);

        // Borrower borrows 500 tokens
        let borrow_1_result = await* borrow_registry.run_operation({ account = borrower; kind = #BORROW_SUPPLY({ amount = 500 }); });
        verify(Result.isOk(borrow_1_result), true, Testify.bool.equal);
        verify(supply_accounting.balances(), [ (dex, 2_000), (protocol, 500), (lender, 9_000), (borrower, 10_500) ], equal_balances);

        // Advance time to accrue some interest
        clock.expect_call(#get_time(#returns(Duration.toTime(#DAYS(100)))), #repeatedly);
        ignore indexer.get_index();

        // Check health before price crash (should be healthy)
        let before_liquidation = borrow_registry.get_loan_position(borrower);
        switch (before_liquidation.loan) {
            case (?loan) {
                verify(loan.health, 1.0, Testify.float.greaterThan);
            };
            case null {
                assert(false); // Should have a position
            };
        };

        // Simulate a collateral price crash
        // To stay healthy, price > (borrowed / (collateral * liquidation_threshold))
        // borrowed = 500, collateral = 2000, liquidation_threshold = 0.75
        // So price must be > (500 / (2000 * 0.75)) = 0.3333 (ignoring the borrowing interests)
        collateral_price_in_supply.value := ?0.3333;

        // Advance time to ensure state update uses new price
        clock.expect_call(#get_time(#returns(Duration.toTime(#DAYS(101)))), #repeatedly);
        ignore indexer.get_index();

        // Check health after price crash (should be unhealthy)
        let after_crash = borrow_registry.get_loan_position(borrower);
        switch (after_crash.loan) {
            case (?loan) {
                verify(loan.health, 1.0, Testify.float.lessThan);
            };
            case null {
                assert(false); // Should have a position
            };
        };

        // Call liquidation
        let liquidation = await* borrow_registry.check_all_positions_and_liquidate();
        verify(Result.isOk(liquidation), true, Testify.bool.equal);

        // After liquidation, the collateral should have been partially liquidated
        let after_liquidation = borrow_registry.get_loan_position(borrower);
        verify(after_liquidation.collateral, 1_030, Testify.nat.equal); // 2000 - 970 (liquidated)
        switch (after_liquidation.loan) {
            case null { assert(false); }; // Not full liquidation, should still have a position
            case (?loan) {
                verify(loan.health, 1.0, Testify.float.greaterThan);
            };
        };

        // 970 collateral was sent to the dex
        verify(collateral_accounting.balances(), [ (dex, 970), (protocol, 1_030), (lender, 0), (borrower, 8_000) ], equal_balances);
        // (970 * 0.33) = 323 supply was sent to the protocol
        verify(supply_accounting.balances(), [ (dex, 1_677), (protocol, 823), (lender, 9_000), (borrower, 10_500) ], equal_balances);

        // Lender withdraws their supply
        let withdraw_result = supply_registry.remove_position({
            id = "supply1";
            share = 1.0; // Full withdrawal
        });
        ignore await* withdrawal_queue.process_pending_withdrawals(); // To effectively withdraw the funds from remove_position
        verify(withdraw_result, #ok(1019), Testify.result(Testify.nat.equal, Testify.text.equal).equal);
        // Lender could only withdraw up to 830 tokens (-3 for fees)
        verify(supply_accounting.balances(), [ (dex, 1_677), (protocol, 3), (lender, 9_820), (borrower, 10_500) ], equal_balances);
    });

    await test("Lender withdrawal triggers withdrawal queue with partial repayment", func() : async() {
        // === Setup Phase ===
        let clock = ClockMock.ClockMock();
        clock.expect_call(#get_time(#returns(Duration.toTime(#DAYS(1)))), #repeatedly);

        let index = { 
            var value = {
                borrow_rate = 0.0;
                supply_rate = 0.0;
                accrued_interests = {
                    fees = 0.0;
                    supply = 0.0;
                };
                borrow_index = {
                    value = 1.0; 
                    timestamp = clock.get_time();
                };
                supply_index = {
                    value = 1.0; 
                    timestamp = clock.get_time();
                };
                timestamp = clock.get_time();  // Day 1
                utilization = {
                    raw_supplied = 0.0;
                    raw_borrowed = 0.0;
                    ratio = 0.0;
                };
            };
        };

        let register = {
            borrow_positions = Map.new<Account, BorrowPosition>();
            supply_positions = Map.new<Text, SupplyPosition>();
            withdrawals = Map.new<Text, Withdrawal>();
            withdraw_queue = Set.new<Text>();
        };

        let admin = fuzz.principal.randomPrincipal(10);
        let protocol = { fuzz.icrc1.randomAccount() with name = "protocol" };
        let lender = { fuzz.icrc1.randomAccount() with name = "lender" };
        let borrower = { fuzz.icrc1.randomAccount() with name = "borrower" };

        let protocol_info = {
            principal = protocol.owner;
            supply = { subaccount = protocol.subaccount; local_balance = { var value = 0; } };
            collateral = { subaccount = protocol.subaccount; local_balance = { var value = 0; } };
        };

        let supply_accounting = LedgerAccounting.LedgerAccounting([ (protocol, 0), (lender, 1_000), (borrower, 1_000)]);
        let collateral_accounting = LedgerAccounting.LedgerAccounting([ (protocol, 0), (lender, 0), (borrower, 5_000)]);
        let supply_ledger = LedgerFungibleFake.LedgerFungibleFake({account = protocol; ledger_accounting = supply_accounting; fee = 0; token_symbol = ""});
        let collateral_ledger = LedgerFungibleFake.LedgerFungibleFake({account = protocol; ledger_accounting = collateral_accounting; fee = 0; token_symbol = ""});

        let collateral_price_in_supply = { var value = ?1.0; }; // 1:1 price

        let dex = DexMock.DexMock();

        let collateral_price_tracker = PriceTracker.PriceTracker({
            dex;
            tracked_price = collateral_price_in_supply;
            pay_ledger = collateral_ledger;
            receive_ledger = supply_ledger;
        });

        // Build the lending system
        let { supply_registry; borrow_registry; withdrawal_queue; } = LendingFactory.build({
            admin;
            collateral_price_tracker;
            protocol_info;
            parameters;
            index;
            register;
            supply_ledger;
            collateral_ledger;
            dex;
            clock;
        });

        // Lender supplies 1000 tokens
        let _ = await* supply_registry.add_position({
            id = "supply1";
            account = lender;
            supplied = 1000;
        });
        verify(supply_accounting.balances(), [ (protocol, 1_000), (lender, 0), (borrower, 1_000) ], equal_balances);

        // Borrower supplies 5000 worth of collateral
        let collateral_1_result = await* borrow_registry.run_operation({ account = borrower; kind = #PROVIDE_COLLATERAL({ amount = 5000 }); });
        verify(Result.isOk(collateral_1_result), true, Testify.bool.equal);
        verify(collateral_accounting.balances(), [ (protocol, 5_000), (lender, 0), (borrower, 0) ], equal_balances);

        // Borrower borrows 900 tokens (almost all liquidity)
        let borrow_1_result = await* borrow_registry.run_operation({ account = borrower; kind = #BORROW_SUPPLY({ amount = 900 }); });
        verify(Result.isOk(borrow_1_result), true, Testify.bool.equal);
        verify(supply_accounting.balances(), [ (protocol, 100), (lender, 0), (borrower, 1_900) ], equal_balances);

        // Lender tries to withdraw full position
        clock.expect_call(#get_time(#returns(Duration.toTime(#DAYS(2)))), #repeatedly);
        let withdraw_result = supply_registry.remove_position({
            id = "supply1";
            share = 1.0;
        });
        ignore await* withdrawal_queue.process_pending_withdrawals(); // To effectively withdraw the funds from remove_position
        verify(withdraw_result, #ok(1002), Testify.result(Testify.nat.equal, Testify.text.equal).equal);

        // At this point, only 100 tokens (-1 for the fees) are available for transfer to the lender
        // The rest is queued in the withdrawal queue, waiting for borrowers to repay
        // The withdrawal queue should have an entry for "supply1" with transferred = 100 and due > 100
        let withdrawal = Map.get(register.withdrawals, Map.thash, "supply1");
        switch (withdrawal) {
            case (?w) {
                verify(w.transferred, 99, Testify.nat.equal);
                verify(w.due > 100, true, Testify.bool.equal);
                // The withdrawal queue should still contain the id
                verify(Set.has(register.withdraw_queue, Set.thash, "supply1"), true, Testify.bool.equal);
            };
            case null {
                assert(false); // Should have a withdrawal entry
            };
        };
        // Lender's balance should have increased by 100
        verify(supply_accounting.balances(), [ (protocol, 1), (lender, 99), (borrower, 1_900) ], equal_balances);

        // Now, borrower repays 900 tokens
        clock.expect_call(#get_time(#returns(Duration.toTime(#DAYS(3)))), #repeatedly);
        let repay_result = await* borrow_registry.run_operation({ account = borrower; kind = #REPAY_SUPPLY({ repayment = #FULL }); });
        verify(Result.isOk(repay_result), true, Testify.bool.equal);

        // After repayment, the withdrawal queue should have processed the rest
        let withdrawal_after = Map.get(register.withdrawals, Map.thash, "supply1");
        switch (withdrawal_after) {
            case (?w) {
                verify(w.transferred, w.due, Testify.nat.equal);
                // The withdrawal queue should no longer contain the id
                verify(Set.has(register.withdraw_queue, Set.thash, "supply1"), false, Testify.bool.equal);
            };
            case null {
                assert(false); // Should have a withdrawal entry
            };
        };
        // Lender should have received all tokens back
        verify(supply_accounting.balances(), [ (protocol, 3), (lender, 1_002), (borrower, 995) ], equal_balances);
    });

})