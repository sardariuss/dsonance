import LendingFactory "../../../src/protocol/lending/LendingFactory";
import PayementTypes "../../../src/protocol/payement/Types";
import LendingTypes "../../../src/protocol/lending/Types";
import LiquidityPoolFake "../../fake/LiquidityPoolFake";
import LedgerFacadeFake "../../fake/LedgerFacadeFake";
import Duration "../../../src/protocol/duration/Duration";
import ClockMock "../../mocks/ClockMock";

import { test; suite; } "mo:test/async";

import Map "mo:map/Map";
import Set "mo:map/Set";
import Fuzz "mo:fuzz";
import Debug "mo:base/Debug";

import { verify; optionalTestify; Testify; } = "../../utils/Testify";

await suite("LendingPool", func(): async() {

    type Account = PayementTypes.Account;
    type BorrowPosition = LendingTypes.BorrowPosition;
    type SupplyPosition = LendingTypes.SupplyPosition;
    type Withdrawal = LendingTypes.Withdrawal;
    type Parameters = LendingTypes.Parameters;
    type SupplyRegister = LendingTypes.SupplyRegister;
    type BorrowRegister = LendingTypes.BorrowRegister;
    type SupplyInput = LendingTypes.SupplyInput;

    let fuzz = Fuzz.fromSeed(0);

    await test("Nominal test", func() : async() {

        // === Setup Phase ===

        let clock = ClockMock.ClockMock();
        // Set time to Day 1
        clock.expect_call(#get_time(#returns(Duration.toTime(#DAYS(1)))), #repeatedly);

        let parameters = {
            liquidation_penalty = 0.1;
            reserve_liquidity = 0.1;
            protocol_fee = 0.1;
            max_slippage = 0.1;
            max_ltv = 0.75;
            liquidation_threshold = 0.85;
            interest_rate_curve = [
                { utilization = 0.0; percentage_rate = 0.02 },
                { utilization = 0.8; percentage_rate = 0.2 },
                { utilization = 1.0; percentage_rate = 1.0 },
            ];
        };

        let state = {
            var supply_rate = 0.0;
            var supply_accrued_interests = 0.0;
            var borrow_index = 1.0;
            var supply_index = 1.0;
            var last_update_timestamp = clock.get_time();  // Day 1
            var utilization = {
                raw_supplied = 0.0;
                raw_borrowed = 0.0;
                ratio = 0.0;
            };
        };

        let register = {
            var collateral_balance: Nat = 0;
            borrow_positions = Map.new<Account, BorrowPosition>();
            supply_positions = Map.new<Text, SupplyPosition>();
            withdrawals = Map.new<Text, Withdrawal>();
            withdraw_queue = Set.new<Text>();
        };

        let supply_ledger = LedgerFacadeFake.LedgerFacadeFake();
        let collateral_ledger = LedgerFacadeFake.LedgerFacadeFake();
        let liquidity_pool = LiquidityPoolFake.LiquidityPoolFake({
            start_price = 100;
        });

        // Build the lending system
        let { indexer; supply_registry; borrow_registry; } = LendingFactory.build({
            clock;
            liquidity_pool;
            parameters;
            state;
            register;
            supply_ledger;
            collateral_ledger;
        });

        // === Initial Assertions ===

        verify(indexer.get_state().borrow_index.value, 1.0, Testify.float.equalEpsilon9);
        verify(supply_ledger.get_balance(), 0, Testify.nat.equal);

        let lender = fuzz.icrc1.randomAccount();
        let borrower = fuzz.icrc1.randomAccount();

        // === Supply Flow ===

        // Lender supplies 1000 tokens — this should increase raw_supplied
        let supply_1_result = await* supply_registry.add_position({
            id = "supply1";
            account = lender;
            supplied = 1000;
        });
        verify(supply_1_result, #ok, Testify.result(Testify.void.equal, Testify.text.equal).equal);

        // Expect raw_supplied to reflect the supply
        verify(indexer.get_state().utilization.raw_supplied, 1000.0, Testify.float.equalEpsilon9);

        // No interest has accrued yet (same timestamp), so indexes should be unchanged
        verify(indexer.get_state().borrow_index.value, 1.0, Testify.float.equalEpsilon9);
        verify(indexer.get_state().supply_index.value, 1.0, Testify.float.equalEpsilon9);

        verify(supply_ledger.get_balance(), 1000, Testify.int.equal);  // Tokens moved into the pool

        // === Advance Time to Day 2 ===

        clock.expect_call(#get_time(#returns(Duration.toTime(#DAYS(2)))), #repeatedly);

        // === Collateral Flow ===

        // Borrower supplies 5000 worth of collateral
        let collateral_1_result = await* borrow_registry.supply_collateral({
            account = borrower;
            amount = 5000;
        });
        verify(collateral_1_result, #ok, Testify.result(Testify.void.equal, Testify.text.equal).equal);
        verify(register.collateral_balance, 5000, Testify.int.equal);

        // === Borrow Flow ===

        // Borrower borrows 200 tokens
        let borrow_1_result = await* borrow_registry.borrow({
            account = borrower;
            amount = 200;
        });
        verify(borrow_1_result, #ok, Testify.result(Testify.void.equal, Testify.text.equal).equal);

        // 200 tokens have left the pool
        verify(supply_ledger.get_balance(), 800, Testify.int.equal);

        // === Post-borrow Expectations ===

        // A borrow has occurred, so utilization > 0 → non-zero borrow rate is established
        // But supply interest was calculated *before* the rate was updated (still 0%)
        // So the borrow index has increased slightly due to non-zero rate, but:
        verify(indexer.get_state().borrow_index.value, 1.0, Testify.float.greaterThan);

        // Supply rate became non-zero only after this update — not enough time passed for interest
        // So supply_index is still 1.0 — this is correct behavior!
        verify(indexer.get_state().supply_index.value, 1.0, Testify.float.equalEpsilon9);

        // === Advance Time to Day 10 (interest should accrue) ===
        clock.expect_call(#get_time(#returns(Duration.toTime(#DAYS(10)))), #repeatedly);

        // Trigger an index update by reading state
        let state_day10 = indexer.get_state();

        // Borrow index should have increased more due to time and utilization
        verify(state_day10.borrow_index.value, 1.0, Testify.float.greaterThan);

        // Supply index should now also have increased due to non-zero supply rate
        verify(state_day10.supply_index.value, 1.0, Testify.float.greaterThan);

        // === Borrower Repayment ===

        // Borrower repays FULL amount, got to 201 tokens to account for accrued interest
        let repay_result = await* borrow_registry.repay({
            account = borrower;
            repayment = #FULL;
        });
        verify(repay_result, #ok, Testify.result(Testify.void.equal, Testify.text.equal).equal);

        // Supply ledger should now hold 1001
        verify(supply_ledger.get_balance(), 1001, Testify.int.equal);

        // Utilization should return to 0
        verify(indexer.get_state().utilization.raw_borrowed, 0.0, Testify.float.equalEpsilon9);
        verify(indexer.get_state().utilization.ratio, 0.0, Testify.float.equalEpsilon9);

        // === Lender Withdrawal ===

        // Advance to Day 20 to ensure some interest has accrued
        clock.expect_call(#get_time(#returns(Duration.toTime(#DAYS(20)))), #repeatedly);

        let withdraw_result = await* supply_registry.remove_position({
            id = "supply1";
            share = 1.0; // Full withdrawal
        });

        verify(withdraw_result, #ok, Testify.result(Testify.void.equal, Testify.text.equal).equal);

        // Final state checks: indexes still increasing, no liquidation, clean balances
        let final_state = indexer.get_state();
        verify(final_state.borrow_index.value, 1.0, Testify.float.greaterThan);
        verify(final_state.supply_index.value, 1.0, Testify.float.greaterThan);

        // Collateral is untouched, since no liquidation
        verify(register.collateral_balance, 5000, Testify.int.equal);

        // === Collateral Withdrawal ===

        // Borrower withdraw 5000 worth of collateral
        let collateral_withdrawal_result = await* borrow_registry.withdraw_collateral({
            account = borrower;
            amount = 5000;
        });
        verify(collateral_withdrawal_result, #ok, Testify.result(Testify.void.equal, Testify.text.equal).equal);
        verify(register.collateral_balance, 0, Testify.int.equal);

    });

    await test("Liquidation on collateral price crash", func() : async() {

        // === Setup Phase (same as nominal) ===

        let clock = ClockMock.ClockMock();
        clock.expect_call(#get_time(#returns(Duration.toTime(#DAYS(1)))), #repeatedly);

        let parameters = {
            liquidation_penalty = 0.1;
            reserve_liquidity = 0.1;
            protocol_fee = 0.1;
            max_slippage = 0.1;
            max_ltv = 0.75;
            liquidation_threshold = 0.85;
            interest_rate_curve = [
                { utilization = 0.0; percentage_rate = 0.02 },
                { utilization = 0.8; percentage_rate = 0.2 },
                { utilization = 1.0; percentage_rate = 1.0 },
            ];
        };

        let state = {
            var supply_rate = 0.0;
            var supply_accrued_interests = 0.0;
            var borrow_index = 1.0;
            var supply_index = 1.0;
            var last_update_timestamp = clock.get_time();  // Day 1
            var utilization = {
                raw_supplied = 0.0;
                raw_borrowed = 0.0;
                ratio = 0.0;
            };
        };

        let register = {
            var collateral_balance: Nat = 0;
            borrow_positions = Map.new<Account, BorrowPosition>();
            supply_positions = Map.new<Text, SupplyPosition>();
            withdrawals = Map.new<Text, Withdrawal>();
            withdraw_queue = Set.new<Text>();
        };

        let supply_ledger = LedgerFacadeFake.LedgerFacadeFake();
        let collateral_ledger = LedgerFacadeFake.LedgerFacadeFake();
        let liquidity_pool = LiquidityPoolFake.LiquidityPoolFake({
            start_price = 1.0; // Start with a price of 1.0
        });

        let { indexer; supply_registry; borrow_registry; } = LendingFactory.build({
            clock;
            liquidity_pool;
            parameters;
            state;
            register;
            supply_ledger;
            collateral_ledger;
        });

        let lender = Fuzz.fromSeed(1).icrc1.randomAccount();
        let borrower = Fuzz.fromSeed(2).icrc1.randomAccount();

        // Lender supplies 1000 tokens
        let supply_1_result = await* supply_registry.add_position({
            id = "supply1";
            account = lender;
            supplied = 1000;
        });
        verify(supply_ledger.get_balance(), 1000, Testify.nat.equal); // Tokens moved into the pool
        verify(supply_1_result, #ok, Testify.result(Testify.void.equal, Testify.text.equal).equal);

        // Borrower supplies 2000 worth of collateral
        let collateral_1_result = await* borrow_registry.supply_collateral({
            account = borrower;
            amount = 2000;
        });
        verify(collateral_1_result, #ok, Testify.result(Testify.void.equal, Testify.text.equal).equal);

        // Borrower borrows 500 tokens
        let borrow_1_result = await* borrow_registry.borrow({
            account = borrower;
            amount = 500;
        });
        verify(borrow_1_result, #ok, Testify.result(Testify.void.equal, Testify.text.equal).equal);
        verify(supply_ledger.get_balance(), 500, Testify.nat.equal); // 1000 supplied - 500 borrowed
        verify(register.collateral_balance, 2000, Testify.int.equal); // Collateral is still 2000

        // Advance time to accrue some interest
        clock.expect_call(#get_time(#returns(Duration.toTime(#DAYS(10)))), #repeatedly);
        ignore indexer.get_state();

        // Check health before price crash (should be healthy)
        let before_liquidation = borrow_registry.query_borrow_position({ account = borrower });
        switch (before_liquidation) {
            case (?qbp) {
                Debug.print("Health before crash: " # debug_show(qbp.health));
                verify(qbp.health, ?1.0, optionalTestify(Testify.float.greaterThan));
            };
            case null {
                verify(false, true, Testify.bool.equal); // Should have a position
            };
        };

        // Simulate a collateral price crash
        liquidity_pool.set_price(0.25); // Drastically lower the price

        // Advance time to ensure state update uses new price
        clock.expect_call(#get_time(#returns(Duration.toTime(#DAYS(11)))), #repeatedly);
        ignore indexer.get_state();

        // Check health after price crash (should be unhealthy)
        let after_crash = borrow_registry.query_borrow_position({ account = borrower });
        switch (after_crash) {
            case (?qbp) {
                Debug.print("Health after crash: " # debug_show(qbp.health));
                verify(qbp.health, ?1.0, optionalTestify(Testify.float.lessThan));
            };
            case null {
                verify(false, true, Testify.bool.equal); // Should have a position
            };
        };

        // Call liquidation
        await* borrow_registry.check_all_positions_and_liquidate();

        // After liquidation, the borrow position should have borrow = null and collateral = 0
        let after_liquidation = borrow_registry.query_borrow_position({ account = borrower });
        switch (after_liquidation) {
            case (?qbp) {
                verify(qbp.position.collateral.amount, 0, Testify.int.equal);
                verify(qbp.position.borrow, null, optionalTestify(Testify.borrow.equal));
            };
            case null {
                verify(false, true, Testify.bool.equal); // Should still have a position object
            };
        };

        // Collateral balance should be 0
        verify(register.collateral_balance, 0, Testify.int.equal);

        // Supply ledger should have increased (liquidation proceeds)
        verify(supply_ledger.get_balance(), 1000, Testify.nat.equal); // 1000 from supply + 500 from liquidation

    });

})