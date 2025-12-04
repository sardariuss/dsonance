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
import Timeline "../../../src/protocol/utils/Timeline";

import { test; suite; } "mo:test/async";

import Map "mo:map/Map";
import Set "mo:map/Set";
import Fuzz "mo:fuzz";
import Result "mo:base/Result";
import Debug "mo:base/Debug";
import Int "mo:base/Int";
import Float "mo:base/Float";

import { verify; Testify; } = "../../utils/Testify";

await suite("LendingPool", func(): async() {

    type Account = LedgerTypes.Account;
    type BorrowPosition = LendingTypes.BorrowPosition;
    type SupplyPosition = LendingTypes.SupplyPosition;
    type RedistributionPosition = LendingTypes.RedistributionPosition;
    type Withdrawal = LendingTypes.Withdrawal;
    type BorrowRegister = LendingTypes.BorrowRegister;
    type RedistributionInput = LendingTypes.RedistributionInput;

    let fuzz = Fuzz.fromSeed(0);
    let equal_balances = LedgerAccounting.testify_balances.equal;

    let parameters : LendingTypes.LendingParameters = {
        supply_cap = 1_000_000_000_000; // arbitrary supply cap
        borrow_cap = 1_000_000_000_000; // arbitrary borrow cap
        reserve_liquidity = 0.1;
        lending_fee_ratio = 0.25;
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

    func unwrap<T>(value: ?T) : T {
        switch(value) {
            case (?v) { v; };
            case (null) { Debug.trap("Value is null") };
        };
    };

    // TODO: Why is there still 2 tokens left in the protocol whereas the accrued fees is less than 1 ?
    await test("Nominal test", func() : async() {

        // === Setup Phase ===

        let clock = ClockMock.ClockMock();
        // Set time to Day 1
        clock.expect_call(#get_time(#returns(Duration.toTime(#DAYS(1)))), #repeatedly);

        let now = clock.get_time();
        let index = Timeline.make1h<LendingTypes.LendingIndex>(now, {
            borrow_rate = 0.0;
            supply_rate = 0.0;
            borrow_index = {
                value = 1.0;
                timestamp = now;
            };
            supply_index = {
                value = 1.0;
                timestamp = now;
            };
            timestamp = now;  // Day 1
            utilization = {
                raw_supplied = 0.0;
                raw_borrowed = 0.0;
                ratio = 0.0;
            };
        });

        let register = {
            borrow_positions = Map.new<Account, BorrowPosition>();
            supply_positions = Map.new<Account, SupplyPosition>();
            redistribution_positions = Map.new<Text, RedistributionPosition>();
            var total_supplied = 0.0;
            var total_raw = 0.0;
            var index = 1.0;
            withdrawals = Map.new<Text, Withdrawal>();
            withdraw_queue = Set.new<Text>();
        };

        let admin = fuzz.principal.randomPrincipal(10);
        let protocol = { fuzz.icrc1.randomAccount() with name = "protocol" };
        let lender = { fuzz.icrc1.randomAccount() with name = "lender" };
        let borrower = { fuzz.icrc1.randomAccount() with name = "borrower" };

        let protocol_info = {
            principal = protocol.owner;
            supply = { 
                subaccount = protocol.subaccount; 
                fees_subaccount = "\01" : Blob; 
                unclaimed_fees = { var value = 0.0; }; 
            };
            collateral = { subaccount = protocol.subaccount; };
        };

        let supply_accounting = LedgerAccounting.LedgerAccounting([(protocol, 0), (lender, 1_000), (borrower, 1_000)]);
        let collateral_accounting = LedgerAccounting.LedgerAccounting([(protocol, 0), (lender, 0), (borrower, 5_000)]);
        let supply_ledger = LedgerFungibleFake.LedgerFungibleFake({account = protocol; ledger_accounting = supply_accounting; ledger_info = {fee = 0; token_symbol = "ckUSDT"; decimals = 6}});
        let collateral_ledger = LedgerFungibleFake.LedgerFungibleFake({account = protocol; ledger_accounting = collateral_accounting; ledger_info = {fee = 0; token_symbol = "ckBTC"; decimals = 8}});

        let collateral_price_in_supply = { var value = ?1.0; }; // 1:1 price

        let dex = DexMock.DexMock();

        let collateral_price_tracker = PriceTracker.SpotPriceTracker({
            price_source = #Dex(dex);
            tracked_price = collateral_price_in_supply;
            pay_ledger = collateral_ledger;
            receive_ledger = supply_ledger;
        });

        // Build the lending system
        let { indexer; supply; redistribution_hub; borrow_registry; withdrawal_queue; } = LendingFactory.build({
            admin;
            protocol_info;
            parameters;
            index;
            register;
            supply_ledger;
            collateral_ledger;
            dex;
            collateral_price_tracker;
        });

        // === Initial Assertions ===
        
        verify(indexer.get_index_now(clock.get_time()).borrow_index.value, 1.0, Testify.float.equalEpsilon9);
        verify(supply_accounting.balances(), [ (protocol, 0), (lender, 1_000), (borrower, 1_000) ], equal_balances);
        verify(collateral_accounting.balances(), [ (protocol, 0), (lender, 0), (borrower, 5_000) ], equal_balances);

        // === Supply Flow ===

        let supplied = 1000;

        // Lender supplies 1000 tokens — this should increase raw_supplied
        let supply_1_result = await* redistribution_hub.add_position({
            id = "supply1";
            account = lender;
            supplied;
        }, clock.get_time());
        verify(Result.isOk(supply_1_result), true, Testify.bool.equal);

        // Expect raw_supplied to reflect the supply
        verify(indexer.get_index_now(clock.get_time()).utilization.raw_supplied, Float.fromInt(supplied), Testify.float.equalEpsilon9);

        // No interest has accrued yet (same timestamp), so indexes should be unchanged
        verify(indexer.get_index_now(clock.get_time()).borrow_index.value, 1.0, Testify.float.equalEpsilon9);
        verify(indexer.get_index_now(clock.get_time()).supply_index.value, 1.0, Testify.float.equalEpsilon9);

        // Tokens moved into the pool
        verify(supply_accounting.balances(), [ (protocol, supplied), (lender, 0), (borrower, 1_000) ], equal_balances);

        // === Advance Time to Day 2 ===

        clock.expect_call(#get_time(#returns(Duration.toTime(#DAYS(2)))), #repeatedly);

        // === Collateral Flow ===

        // Borrower supplies 5000 worth of collateral
        let collateral_1_result = await* borrow_registry.run_operation(clock.get_time(), { account = borrower; amount = 5000; kind = #PROVIDE_COLLATERAL; });
        verify(Result.isOk(collateral_1_result), true, Testify.bool.equal);
        verify(collateral_accounting.balances(), [ (protocol, 5_000), (lender, 0), (borrower, 0) ], equal_balances);

        // === Borrow Flow ===

        // Borrower borrows 200 tokens
        let borrow_1_result = await* borrow_registry.run_operation(clock.get_time(), { account = borrower; amount = 200; kind = #BORROW_SUPPLY; });
        verify(Result.isOk(borrow_1_result), true, Testify.bool.equal);

        // 200 tokens have left the pool
        verify(supply_accounting.balances(), [ (protocol, 800), (lender, 0), (borrower, 1200) ], equal_balances);

        // === Post-borrow Expectations ===

        // Still 0 because no time has passed yet
        verify(indexer.get_index_now(clock.get_time()).borrow_index.value, 1.0, Testify.float.equalEpsilon9);
        verify(indexer.get_index_now(clock.get_time()).supply_index.value, 1.0, Testify.float.equalEpsilon9);

        // === Advance Time to Day 100 (interest should accrue) ===
        clock.expect_call(#get_time(#returns(Duration.toTime(#DAYS(100)))), #repeatedly);

        // Trigger an index update by reading state
        let state_day100 = indexer.get_index_now(clock.get_time());

        // Borrow index should have increased more due to time and utilization
        verify(state_day100.borrow_index.value, 1.0, Testify.float.greaterThan);
        // Supply index should now also have increased due to non-zero supply rate
        verify(state_day100.supply_index.value, 1.0, Testify.float.greaterThan);

        // === Borrower Repayment ===

        // No fee accrued before repayment
        verify(supply.get_unclaimed_fees(), 0, Testify.nat.equal);
        Debug.print("Unclaimed fees: " # debug_show(protocol_info.supply.unclaimed_fees.value));
        let supply_info_before = redistribution_hub.get_supply_info(clock.get_time());
        Debug.print("Accrued interests: " # debug_show(supply_info_before.accrued_interests));

        // Borrower repays full amount, got to 201 tokens to account for accrued interest
        let { current_owed } = unwrap(borrow_registry.get_loan_position(clock.get_time(), borrower).loan);
        let repay_result = await* borrow_registry.run_operation(clock.get_time(), { 
            account = borrower;
            amount = Int.abs(Float.toInt(current_owed));
            kind = #REPAY_SUPPLY({ max_slippage_amount = 1; }); // Use slippage of 1 because the amount has been truncated
        });
        verify(Result.isOk(repay_result), true, Testify.bool.equal);

        verify(supply_accounting.balances(), [ (protocol, 1_004), (lender, 0), (borrower, 996) ], equal_balances);
        Debug.print("Unclaimed fees: " # debug_show(protocol_info.supply.unclaimed_fees.value));
        let supply_info_after = redistribution_hub.get_supply_info(clock.get_time());
        Debug.print("Accrued interests: " # debug_show(supply_info_after.accrued_interests));
        verify(supply.get_unclaimed_fees(), 1, Testify.nat.equal);

        // Utilization should return to 0
        verify(indexer.get_index_now(clock.get_time()).utilization.raw_borrowed, 0.0, Testify.float.equalEpsilon9);
        verify(indexer.get_index_now(clock.get_time()).utilization.ratio, 0.0, Testify.float.equalEpsilon9);

        // === Lender Withdrawal ===

        let supply_info_withdraw = redistribution_hub.get_supply_info(clock.get_time());
        let interest_amount = Int.abs(Float.toInt(supply_info_withdraw.accrued_interests));
        let withdraw_result = redistribution_hub.remove_position({
            id = "supply1";
            interest_amount;
            time = clock.get_time();
        });
        verify(withdraw_result, #ok(supplied + interest_amount), Testify.result(Testify.nat.equal, Testify.text.equal).equal);

        Debug.print("Accrued interests: " # debug_show(supply_info_withdraw.accrued_interests));
        
        ignore await* withdrawal_queue.process_pending_withdrawals(clock.get_time());
        verify(supply_accounting.balances(), [ (protocol, 2), (lender, supplied + interest_amount), (borrower, 996) ], equal_balances);

        // Final state checks: indexes still increasing, no liquidation, clean balances
        let final_state = indexer.get_index_now(clock.get_time());
        verify(final_state.borrow_index.value, 1.0, Testify.float.greaterThan);
        verify(final_state.supply_index.value, 1.0, Testify.float.greaterThan);
        // Collateral is untouched, since no liquidation
        verify(collateral_accounting.balances(), [ (protocol, 5_000), (lender, 0), (borrower, 0) ], equal_balances);

        // === Collateral Withdrawal ===

        // Borrower withdraw 5000 worth of collateral
        let collateral_withdrawal_result = await* borrow_registry.run_operation(clock.get_time(), { 
            account = borrower; 
            amount = 5000;
            kind = #WITHDRAW_COLLATERAL;
        });
        verify(Result.isOk(collateral_withdrawal_result), true, Testify.bool.equal);
        verify(collateral_accounting.balances(), [ (protocol, 0), (lender, 0), (borrower, 5_000) ], equal_balances);
    });

    await test("Liquidation on collateral price crash", func() : async() {

        // === Setup Phase (same as nominal) ===

        let clock = ClockMock.ClockMock();
        clock.expect_call(#get_time(#returns(Duration.toTime(#DAYS(1)))), #repeatedly);

        let now = clock.get_time();
        let index = Timeline.make1h<LendingTypes.LendingIndex>(now, {
            borrow_rate = 0.0;
            supply_rate = 0.0;
            borrow_index = {
                value = 1.0;
                timestamp = now;
            };
            supply_index = {
                value = 1.0;
                timestamp = now;
            };
            timestamp = now;  // Day 1
            utilization = {
                raw_supplied = 0.0;
                raw_borrowed = 0.0;
                ratio = 0.0;
            };
        });

        let register = {
            borrow_positions = Map.new<Account, BorrowPosition>();
            supply_positions = Map.new<Account, SupplyPosition>();
            redistribution_positions = Map.new<Text, RedistributionPosition>();
            var total_supplied = 0.0;
            var total_raw = 0.0;
            var index = 1.0;
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
            supply = { 
                subaccount = protocol.subaccount; 
                fees_subaccount = "\01" : Blob; 
                unclaimed_fees = { var value = 0.0; }; 
            };
            collateral = { subaccount = protocol.subaccount; };
        };

        let supply_accounting = LedgerAccounting.LedgerAccounting([(dex, 2_000), (protocol, 0), (lender, 10_000), (borrower, 10_000)]);
        let collateral_accounting = LedgerAccounting.LedgerAccounting([(dex, 0), (protocol, 0), (lender, 0), (borrower, 10_000)]);
        let supply_ledger = LedgerFungibleFake.LedgerFungibleFake({account = protocol; ledger_accounting = supply_accounting; ledger_info = {fee = 0; token_symbol = "ckUSDT"; decimals = 6}});
        let collateral_ledger = LedgerFungibleFake.LedgerFungibleFake({account = protocol; ledger_accounting = collateral_accounting; ledger_info = {fee = 0; token_symbol = "ckBTC"; decimals = 8}});

        let collateral_price_in_supply = { var value = ?1.0; }; // Start with 1:1 price

        let dex_fake = DexFake.DexFake({ 
            account = dex;
            config = {
                pay_accounting = collateral_accounting;
                receive_accounting = supply_accounting;
                pay_token = "ckBTC";
                receive_token = "ckUSDT";
            };
            price = collateral_price_in_supply;
        });

        let collateral_price_tracker = PriceTracker.SpotPriceTracker({
            price_source = #Dex(dex_fake);
            tracked_price = collateral_price_in_supply;
            pay_ledger = collateral_ledger;
            receive_ledger = supply_ledger;
        });

        // Build the lending system
        let { indexer; redistribution_hub; borrow_registry; withdrawal_queue; } = LendingFactory.build({
            admin;
            collateral_price_tracker;
            protocol_info;
            parameters;
            index;
            register;
            supply_ledger;
            collateral_ledger;
            dex = dex_fake;
        });

        // === Initial Assertions ===
        
        verify(indexer.get_index_now(clock.get_time()).borrow_index.value, 1.0, Testify.float.equalEpsilon9);

        // Lender supplies 1000 tokens
        let supply_1_result = await* redistribution_hub.add_position({
            id = "supply1";
            account = lender;
            supplied = 1000;
        }, clock.get_time());
        verify(Result.isOk(supply_1_result), true, Testify.bool.equal);
        verify(supply_accounting.balances(), [ (dex, 2_000), (protocol, 1_000), (lender, 9_000), (borrower, 10_000) ], equal_balances);
        
        // Borrower supplies 2000 worth of collateral
        let collateral_1_result = await* borrow_registry.run_operation(clock.get_time(), { account = borrower; amount = 2000; kind = #PROVIDE_COLLATERAL; });
        verify(Result.isOk(collateral_1_result), true, Testify.bool.equal);
        verify(collateral_accounting.balances(), [ (dex, 0), (protocol, 2_000), (lender, 0), (borrower, 8_000) ], equal_balances);

        // Borrower borrows 500 tokens
        let borrow_1_result = await* borrow_registry.run_operation(clock.get_time(), { account = borrower; amount = 500; kind = #BORROW_SUPPLY; });
        verify(Result.isOk(borrow_1_result), true, Testify.bool.equal);
        verify(supply_accounting.balances(), [ (dex, 2_000), (protocol, 500), (lender, 9_000), (borrower, 10_500) ], equal_balances);

        // Advance time to accrue some interest
        clock.expect_call(#get_time(#returns(Duration.toTime(#DAYS(100)))), #repeatedly);
        ignore indexer.get_index_now(clock.get_time());

        // Check health before price crash (should be healthy)
        verify(unwrap(borrow_registry.get_loan_position(clock.get_time(), borrower).loan).health, 1.0, Testify.float.greaterThan);

        // Simulate a collateral price crash
        // To stay healthy, price > (borrowed / (collateral * liquidation_threshold))
        // borrowed = 500, collateral = 2000, liquidation_threshold = 0.75
        // So price must be > (500 / (2000 * 0.75)) = 0.3333 (ignoring the borrowing interests)
        collateral_price_in_supply.value := ?0.3333;

        // Advance time to ensure state update uses new price
        clock.expect_call(#get_time(#returns(Duration.toTime(#DAYS(101)))), #repeatedly);
        ignore indexer.get_index_now(clock.get_time());

        // Check health after price crash (should be unhealthy)
        verify(unwrap(borrow_registry.get_loan_position(clock.get_time(), borrower).loan).health, 1.0, Testify.float.lessThan);

        // Call liquidation
        let liquidation = await* borrow_registry.check_all_positions_and_liquidate(clock.get_time());
        verify(Result.isOk(liquidation), true, Testify.bool.equal);

        // After liquidation, the collateral should have been partially liquidated
        let after_liquidation = borrow_registry.get_loan_position(clock.get_time(), borrower);
        verify(after_liquidation.collateral, 1_043, Testify.nat.equal); // Adjusted for corrected utilization ratio calculation
        // Not full liquidation, should still have a position
        verify(unwrap(after_liquidation.loan).health, 1.0, Testify.float.greaterThan);

        // Collateral was sent to the dex, adjusted for corrected utilization ratio
        verify(collateral_accounting.balances(), [ (dex, 957), (protocol, 1_043), (lender, 0), (borrower, 8_000) ], equal_balances);
        // Supply accounting adjusted for corrected utilization ratio
        verify(supply_accounting.balances(), [ (dex, 1_682), (protocol, 818), (lender, 9_000), (borrower, 10_500) ], equal_balances);

        // Lender withdraws their supply
        let withdraw_result = redistribution_hub.remove_position({
            id = "supply1";
            interest_amount = 10; // Arbitrarily take 10 tokens as interest
            time = clock.get_time();
        });
        verify(withdraw_result, #ok(1010), Testify.result(Testify.nat.equal, Testify.text.equal).equal);

        ignore await* withdrawal_queue.process_pending_withdrawals(clock.get_time()); // To effectively withdraw the funds from remove_position

        // Lender could only withdraw up to 823 tokens
        verify(supply_accounting.balances(), [ (dex, 1_682), (protocol, 0), (lender, 9_818), (borrower, 10_500) ], equal_balances);

        // TODO: need to know how much is pending in the withdrawal queue
    });

    await test("Lender withdrawal triggers withdrawal queue with partial repayment", func() : async() {
        // === Setup Phase ===
        let clock = ClockMock.ClockMock();
        clock.expect_call(#get_time(#returns(Duration.toTime(#DAYS(1)))), #repeatedly);

        let now = clock.get_time();
        let index = Timeline.make1h<LendingTypes.LendingIndex>(now, {
            borrow_rate = 0.0;
            supply_rate = 0.0;
            borrow_index = {
                value = 1.0;
                timestamp = now;
            };
            supply_index = {
                value = 1.0;
                timestamp = now;
            };
            timestamp = now;  // Day 1
            utilization = {
                raw_supplied = 0.0;
                raw_borrowed = 0.0;
                ratio = 0.0;
            };
        });

        let register = {
            borrow_positions = Map.new<Account, BorrowPosition>();
            supply_positions = Map.new<Account, SupplyPosition>();
            redistribution_positions = Map.new<Text, RedistributionPosition>();
            var total_supplied = 0.0;
            var total_raw = 0.0;
            var index = 1.0;
            withdrawals = Map.new<Text, Withdrawal>();
            withdraw_queue = Set.new<Text>();
        };

        let admin = fuzz.principal.randomPrincipal(10);
        let protocol = { fuzz.icrc1.randomAccount() with name = "protocol" };
        let lender = { fuzz.icrc1.randomAccount() with name = "lender" };
        let borrower = { fuzz.icrc1.randomAccount() with name = "borrower" };

        let protocol_info = {
            principal = protocol.owner;
            supply = { 
                subaccount = protocol.subaccount; 
                fees_subaccount = "\01" : Blob; 
                unclaimed_fees = { var value = 0.0; }; 
            };
            collateral = { subaccount = protocol.subaccount; };
        };

        let supply_accounting = LedgerAccounting.LedgerAccounting([ (protocol, 0), (lender, 1_000), (borrower, 1_000)]);
        let collateral_accounting = LedgerAccounting.LedgerAccounting([ (protocol, 0), (lender, 0), (borrower, 5_000)]);
        let supply_ledger = LedgerFungibleFake.LedgerFungibleFake({account = protocol; ledger_accounting = supply_accounting; ledger_info = {fee = 0; token_symbol = "ckUSDT"; decimals = 6}});
        let collateral_ledger = LedgerFungibleFake.LedgerFungibleFake({account = protocol; ledger_accounting = collateral_accounting; ledger_info = {fee = 0; token_symbol = "ckBTC"; decimals = 8}});

        let collateral_price_in_supply = { var value = ?1.0; }; // 1:1 price

        let dex = DexMock.DexMock();

        let collateral_price_tracker = PriceTracker.SpotPriceTracker({
            price_source = #Dex(dex);
            tracked_price = collateral_price_in_supply;
            pay_ledger = collateral_ledger;
            receive_ledger = supply_ledger;
        });

        // Build the lending system
        let { supply; redistribution_hub; borrow_registry; withdrawal_queue; } = LendingFactory.build({
            admin;
            collateral_price_tracker;
            protocol_info;
            parameters;
            index;
            register;
            supply_ledger;
            collateral_ledger;
            dex;
        });

        // Lender supplies 1000 tokens
        ignore await* redistribution_hub.add_position({
            id = "supply1";
            account = lender;
            supplied = 1000;
        }, clock.get_time());
        verify(supply_accounting.balances(), [ (protocol, 1_000), (lender, 0), (borrower, 1_000) ], equal_balances);

        // Borrower supplies 5000 worth of collateral
        let collateral_1_result = await* borrow_registry.run_operation(clock.get_time(), { account = borrower; amount = 5000; kind = #PROVIDE_COLLATERAL; });
        verify(Result.isOk(collateral_1_result), true, Testify.bool.equal);
        verify(collateral_accounting.balances(), [ (protocol, 5_000), (lender, 0), (borrower, 0) ], equal_balances);

        // Borrower borrows 900 tokens (almost all liquidity)
        let borrow_1_result = await* borrow_registry.run_operation(clock.get_time(), { account = borrower; amount = 900; kind = #BORROW_SUPPLY; });
        verify(Result.isOk(borrow_1_result), true, Testify.bool.equal);
        verify(supply_accounting.balances(), [ (protocol, 100), (lender, 0), (borrower, 1_900) ], equal_balances);

        // Lender tries to withdraw full position
        clock.expect_call(#get_time(#returns(Duration.toTime(#DAYS(2)))), #repeatedly);
        let withdraw_result = redistribution_hub.remove_position({
            id = "supply1";
            interest_amount = 1; // Adjusted for corrected utilization ratio - less interest accrued
            time = clock.get_time();
        });
        ignore await* withdrawal_queue.process_pending_withdrawals(clock.get_time()); // To effectively withdraw the funds from remove_position
        verify(withdraw_result, #ok(1001), Testify.result(Testify.nat.equal, Testify.text.equal).equal);

        // At this point, only 100 tokens are available for transfer to the lender
        // The rest is queued in the withdrawal queue, waiting for borrowers to repay
        // The withdrawal queue should have an entry for "supply1" with transferred = 100 and due > 100
        let withdrawal = Map.get(register.withdrawals, Map.thash, "supply1");
        switch (withdrawal) {
            case (?w) {
                verify(w.transferred, 100, Testify.nat.equal);
                verify(w.due > 100, true, Testify.bool.equal);
                // The withdrawal queue should still contain the id
                verify(Set.has(register.withdraw_queue, Set.thash, "supply1"), true, Testify.bool.equal);
            };
            case null {
                assert(false); // Should have a withdrawal entry
            };
        };
        // Lender's balance should have increased by 100
        verify(supply_accounting.balances(), [ (protocol, 0), (lender, 100), (borrower, 1_900) ], equal_balances);

        // No fees before repayment
        verify(supply.get_unclaimed_fees(), 0, Testify.nat.equal);

        // Now, borrower repays 900 tokens
        clock.expect_call(#get_time(#returns(Duration.toTime(#DAYS(3)))), #repeatedly);
        let { current_owed } = unwrap(borrow_registry.get_loan_position(clock.get_time(), borrower).loan);
        let repay_result = await* borrow_registry.run_operation(clock.get_time(), { 
            account = borrower;
            amount = Int.abs(Float.toInt(current_owed));
            kind = #REPAY_SUPPLY({ max_slippage_amount = 1; }); // Use slippage of 1 because the amount has been truncated
        });
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
        verify(supply_accounting.balances(), [ (protocol, 3), (lender, 1_001), (borrower, 996) ], equal_balances);
        verify(supply.get_unclaimed_fees(), 1, Testify.nat.equal);
    });

    await test("Health factor calculation with realistic decimal amounts", func() : async() {
        // === Setup Phase ===
        let clock = ClockMock.ClockMock();
        clock.expect_call(#get_time(#returns(Duration.toTime(#DAYS(1)))), #repeatedly);

        let now = clock.get_time();
        let index = Timeline.make1h<LendingTypes.LendingIndex>(now, {
            borrow_rate = 0.0;
            supply_rate = 0.0;
            borrow_index = {
                value = 1.0;
                timestamp = now;
            };
            supply_index = {
                value = 1.0;
                timestamp = now;
            };
            timestamp = now;  // Day 1
            utilization = {
                raw_supplied = 0.0;
                raw_borrowed = 0.0;
                ratio = 0.0;
            };
        });

        let register = {
            borrow_positions = Map.new<Account, BorrowPosition>();
            supply_positions = Map.new<Account, SupplyPosition>();
            redistribution_positions = Map.new<Text, RedistributionPosition>();
            var total_supplied = 0.0;
            var total_raw = 0.0;
            var index = 1.0;
            withdrawals = Map.new<Text, Withdrawal>();
            withdraw_queue = Set.new<Text>();
        };

        let admin = fuzz.principal.randomPrincipal(10);
        let protocol = { fuzz.icrc1.randomAccount() with name = "protocol" };
        let lender = { fuzz.icrc1.randomAccount() with name = "lender" };
        let borrower = { fuzz.icrc1.randomAccount() with name = "borrower" };

        let protocol_info = {
            principal = protocol.owner;
            supply = { 
                subaccount = protocol.subaccount; 
                fees_subaccount = "\01" : Blob; 
                unclaimed_fees = { var value = 0.0; }; 
            };
            collateral = { subaccount = protocol.subaccount; };
        };

        // Use realistic decimal amounts
        // 1 BTC = 100_000_000 satoshis (8 decimals)
        // 50k USDT = 50_000_000_000 micro-USDT (6 decimals)
        // 1M USDT = 1_000_000_000_000 micro-USDT
        let supply_accounting = LedgerAccounting.LedgerAccounting([
            (protocol, 0), 
            (lender, 1_000_000_000_000), // 1M USDT
            (borrower, 0)
        ]);
        let collateral_accounting = LedgerAccounting.LedgerAccounting([
            (protocol, 0), 
            (lender, 0), 
            (borrower, 100_000_000) // 1 BTC
        ]);
        let supply_ledger = LedgerFungibleFake.LedgerFungibleFake({
            account = protocol; 
            ledger_accounting = supply_accounting; 
            ledger_info = {
                fee = 0; 
                token_symbol = "ckUSDT";
                decimals = 6;
            };
        });
        let collateral_ledger = LedgerFungibleFake.LedgerFungibleFake({
            account = protocol; 
            ledger_accounting = collateral_accounting; 
            ledger_info = {
                fee = 0; 
                token_symbol = "ckBTC";
                decimals = 8;
            };
        });

        // Use token price as Kong would return: 50,000 USDT per BTC (not micro-USDT per satoshi)
        let collateral_price_in_supply : { var value: ?Float } = { var value = ?50000.0; }; // Token price in USDT per BTC
        
        let dex_fake = DexFake.DexFake({ 
            account = protocol;
            config = {
                pay_accounting = collateral_accounting;
                receive_accounting = supply_accounting;
                pay_token = "ckBTC";
                receive_token = "ckUSDT";
            };
            price = collateral_price_in_supply;
        });

        let collateral_price_tracker = PriceTracker.SpotPriceTracker({
            price_source = #Dex(dex_fake);
            tracked_price = collateral_price_in_supply;
            pay_ledger = collateral_ledger;
            receive_ledger = supply_ledger;
        });

        // Build the lending system
        let { redistribution_hub; borrow_registry; } = LendingFactory.build({
            admin;
            protocol_info;
            parameters;
            index;
            register;
            supply_ledger;
            collateral_ledger;
            dex = dex_fake;
            collateral_price_tracker;
        });

        // Trigger price fetch to normalize the price with decimals
        let fetch_result = await* collateral_price_tracker.fetch_price();
        switch(fetch_result) {
            case(#err(error)) { Debug.trap("Failed to fetch price: " # error); };
            case(#ok(_)) { /* Price fetched successfully */ };
        };

        // === Test Scenario ===
        
        // Lender supplies 1M USDT
        let supply_1_result = await* redistribution_hub.add_position({
            id = "supply1";
            account = lender;
            supplied = 1_000_000_000_000; // 1M USDT in micro-USDT
        }, clock.get_time());
        verify(Result.isOk(supply_1_result), true, Testify.bool.equal);

        // Borrower provides 1 BTC collateral (100M satoshis)
        let collateral_1_result = await* borrow_registry.run_operation(clock.get_time(), { 
            account = borrower; 
            amount = 100_000_000; // 1 BTC in satoshis
            kind = #PROVIDE_COLLATERAL; 
        });
        verify(Result.isOk(collateral_1_result), true, Testify.bool.equal);

        // Borrower borrows 30k USDT (should be safe with 1 BTC at $50k)
        let borrow_1_result = await* borrow_registry.run_operation(clock.get_time(), { 
            account = borrower; 
            amount = 30_000_000_000; // 30k USDT in micro-USDT
            kind = #BORROW_SUPPLY; 
        });
        verify(Result.isOk(borrow_1_result), true, Testify.bool.equal);

        // Check health factor - should be reasonable (around 1.25)
        // Expected calculation:
        // - Collateral: 1 BTC = $50k
        // - Borrowed: 30k USDT
        // - LTV = 30k / 50k = 0.6
        // - Health = liquidation_threshold / LTV = 0.75 / 0.6 = 1.25
        let loan_position = borrow_registry.get_loan_position(clock.get_time(), borrower);
        let health = unwrap(loan_position.loan).health;
        
        // Verify the health is around 1.25
        verify(health, 1.24, Testify.float.greaterThan);
        verify(health, 1.26, Testify.float.lessThan);
    });

})