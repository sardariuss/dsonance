import LendingFactory "../../src/protocol/lending/LendingFactory";
import PayementTypes "../../src/protocol/payement/Types";
import LendingTypes "../../src/protocol/lending/Types";
import LedgerFacadeMock "../mocks/LedgerFacadeMock";
import LiquidityPoolMock "../mocks/LiquidityPoolMock";
import Duration "../../src/protocol/duration/Duration";

import { test; suite; } "mo:test/async";
import Float "mo:base/Float";
import Int "mo:base/Int";

import Map "mo:map/Map";
import Set "mo:map/Set";
import Fuzz "mo:fuzz";

import { verify; Testify; } = "../utils/Testify";

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

    await test("First", func() : async() {

        var time = 0;

        let parameters = {
            liquidation_penalty = 0.1;
            reserve_liquidity = 0.1;
            protocol_fee = 0.1;
            max_slippage = 0.1;
            max_ltv = 0.75;
            liquidation_threshold = 0.85;
            interest_rate_curve = [
                {
                    utilization = 0.0;
                    percentage_rate = 0.02
                },
                {
                    utilization = 0.8;
                    percentage_rate = 0.2
                },
                {
                    utilization = 1.0;
                    percentage_rate = 1.0
                },
            ];
        };
        let state = {
            var supply_rate: Float = 0.0;
            var supply_accrued_interests: Float = 0.0;
            var borrow_index: Float = 1.0;
            var supply_index: Float = 1.0;
            var last_update_timestamp: Nat = time;
            var supply_balance: Int = 0;
            var collateral_balance: Int = 0;
        };
        let borrow_register = {
            var collateral_balance: Nat = 0;
            var total_borrowed: Float = 0.0;
            map = Map.new<Account, BorrowPosition>();
        };

        let supply_register = {
            var total_supplied: Nat = 0;
            positions = Map.new<Text, SupplyPosition>();
            withdrawals = Map.new<Text, Withdrawal>();
            withdraw_queue = Set.new<Text>();
        };

        let supply_ledger = LedgerFacadeMock.LedgerFacadeMock();
        supply_ledger.expect_call(#transfer_from(#returns(#ok(0))), #repeatedly);
        // @todo: is there no other way to do this?
        let args = {
            to = fuzz.icrc1.randomAccount();
            from_subaccount = null;
            amount = 0;
            fee = null;
            memo = null;
            created_at_time = null;
        };
        supply_ledger.expect_call(#transfer(#returns({ args; result = #ok(0); })), #repeatedly);
        let collateral_ledger = LedgerFacadeMock.LedgerFacadeMock();
        collateral_ledger.expect_call(#transfer_from(#returns(#ok(0))), #repeatedly);

        let get_collateral_spot_in_asset = func({ time: Nat; }) : Float { 1.0; };
        
        let { indexer; supply_registry; borrow_registry; withdrawal_queue; } = LendingFactory.build({
            parameters;
            state;
            borrow_register;
            supply_register;
            supply_ledger;
            collateral_ledger;
            get_collateral_spot_in_asset;
        });

        // Test initial state
        verify<Float>(lending_pool.get_borrow_index({ time }).value, 1.0, Testify.float.equalEpsilon9);
        verify<Float>(lending_pool.get_available_liquidity(), 0.0, Testify.float.equalEpsilon9);
        verify<Float>(lending_pool.get_virtual_available({ time }), 0.0, Testify.float.equalEpsilon9);

        let lender = fuzz.icrc1.randomAccount();
        let borrower = fuzz.icrc1.randomAccount();
        time := Duration.toTime(#DAYS(1));

        // Lender supplies some assets
        let supply_1_result = await* supply_registry.add_position({
            id = "supply1";
            timestamp = time;
            account = lender;
            supplied = 1000;
        });
        verify(supply_1_result, #ok, Testify.result(Testify.void.equal, Testify.text.equal).equal);
        verify(state.supply_balance, 1000, Testify.int.equal);
        verify(state.borrow_index, 1.0, Testify.float.equalEpsilon9);
        verify(state.supply_index, 1.0, Testify.float.equalEpsilon9);
        verify(lending_pool.get_available_liquidity(), 1000.0, Testify.float.equalEpsilon9);

        //time := Duration.toTime(#DAYS(2));

        // Borrower supplies some collateral
        let collateral_1_result = await* lending_pool.supply_collateral({
            account = borrower;
            amount = 5000;
        });
        verify(collateral_1_result, #ok, Testify.result(Testify.void.equal, Testify.text.equal).equal);
        verify(state.collateral_balance, 5000, Testify.int.equal);

        // Borrower borrows some assets
        let borrow_1_result = await* lending_pool.borrow({
            account = borrower;
            amount = 500;
            time;
        });
        verify(borrow_1_result, #ok, Testify.result(Testify.void.equal, Testify.text.equal).equal);
        verify(state.collateral_balance, 5000, Testify.int.equal);
        verify(state.supply_balance, 500, Testify.int.equal);
        verify(lending_pool.get_available_liquidity(), 500.0, Testify.float.equalEpsilon9);

        // @todo: I am surprised that it is less than 500 (i.e. 499.99)
        verify(lending_pool.get_virtual_available({ time }), 500.0, Testify.float.equalEpsilon9);

    });

})