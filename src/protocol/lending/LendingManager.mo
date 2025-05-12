import Result "mo:base/Result";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Nat "mo:base/Nat";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Buffer "mo:base/Buffer";

import Map "mo:map/Map";

import Register "../utils/Register";
import LedgerFacade "../payement/LedgerFacade";
import Math "../utils/Math";
import Types "../Types";
import LendingPool "LendingPool";

module {

    type Account = Types.Account;
    type TxIndex = Types.TxIndex;
    type Register<T> = Types.Register<T>;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type Transfer = Types.Transfer;

    type DebtEntry = { 
        timestamp: Nat;
        amount: Float;
    };

    type BorrowPosition = {
        timestamp: Nat;
        account: Account;
        collateral_tx: [TxIndex];
        borrow_tx: [TxIndex];
        collateral: Float;
        borrowed: Float;
        borrow_index: Float;
    };

    type WithdrawEntry = {
        account: Account;
        supplied: Nat;
        due: Nat;
        var state: {
            #PENDING;
            #TRIGGERED;
            #COMPLETED;
        };
    };

    type SellCollateralQuery = ({
        amount: Nat;
        max_slippage: Float;
    }) -> async* Result<{ sold_amount: Nat }, Text>;

    // @todo: think about possible rounding errors and cast between int and float
    public class LendingManager({
        lending_pool: LendingPool.LendingPool;
        asset_ledger: LedgerFacade.LedgerFacade;
        collateral_ledger: LedgerFacade.LedgerFacade;
        sell_collateral: SellCollateralQuery;
        max_slippage: Float;
        asset_accounting: {
            var reserve: Float;
            var unsolved_debts: [DebtEntry];
        };
    }) {

        func reimburse_collateral({
            account: Account;
        }) : async* Result<(), Text> {

            let position = switch(lending_pool.get_borrow_position({ account; })){
                case(null) { return #err("Borrow position not found"); };
                case(?p) { p };
            };

            if (position.borrowed > 0.0){
                return #err("The borrow position is not fully repaid yet");
            };
                
            // Transfer back the collateral
            switch((await* collateral_ledger.transfer({ to = account; amount = Int.abs(Float.toInt(position.collateral)); })).result){
                case(#err(_)) { 
                    return #err("Collateral reimbursement failed");
                };
                case(#ok(_)) {};
            };

            #ok;
        };

        /// Liquidate borrow positions if their health factor is below 1.0.
        /// @todo: this function access shall be restricted to the protocol only and called by a timer
        public func check_all_positions_and_liquidate({ 
            time: Nat;
            collateral_spot_in_asset: () -> Float;
        }) : async*() {

            lending_pool.accrue_interests_and_update_rates({ time; });

            let to_liquidate = Buffer.Buffer<BorrowPosition>(0);
            var sum_borrowed = 0.0;
            var sum_collateral = 0.0;

            label liquidation_loop for (position in lending_pool.get_borrow_positions()){

                if (position.borrowed <= 0.0) {
                    Debug.print("The borrow position has already been repaid");
                    continue liquidation_loop;
                };

                let is_healthy = lending_pool.is_healthy({ position; });
                let is_within_borrow_duration = lending_pool.is_within_borrow_duration({ position; time; });
                
                // Liquidate if not healthy or not within the borrow duration
                if (not is_healthy or not is_within_borrow_duration){
                    to_liquidate.add(position);
                    sum_borrowed += position.borrowed;
                    sum_collateral += position.collateral;
                };
            };

            // Ceil the collateral to be sure to sell enough
            let collateral_to_sell = Int.abs(Float.toInt(Float.ceil(sum_collateral)));

            let collateral_sold = switch(await* sell_collateral({ amount = collateral_to_sell; max_slippage; })){
                case(#err(_)) { 
                    Debug.print("Collateral sale failed");
                    return; 
                };
                case(#ok({ sold_amount; })) { sold_amount; };
            };

            let ratio_sold = Float.fromInt(collateral_sold) / Float.fromInt(collateral_to_sell);

            // @todo: the total borrowed shall take the slippage into account because otherwise the
            // available total liquidity computation will be wrong (i.e. not reflect the amount actually available)
            
            // Update the positions
            for (position in to_liquidate.vals()) {
                ignore lending_pool.slash_borrow({ 
                    account = position.account;
                    borrow_amount = position.borrowed * ratio_sold;
                    collateral_amount = position.collateral * ratio_sold;
                });
            };

            let value_sold = Float.fromInt(collateral_sold) * collateral_spot_in_asset();
            let value_debt = sum_borrowed * ratio_sold;

            let difference = value_sold - value_debt;

            // @todo: need to take protocol fees

            if (difference >= 0.0) {
                asset_accounting.reserve += difference;
            } else {
                Debug.print("⚠️ Bad debt: liquidation proceeds are insufficient");
                asset_accounting.unsolved_debts := Array.append(asset_accounting.unsolved_debts, [{ timestamp = time; amount = difference; }]);
            };
        };

        // @todo: should be available to the protocol only
        public func solve_debts_with_reserve() {

            let debts_left = Buffer.Buffer<DebtEntry>(0);

            for(debt in Array.vals(asset_accounting.unsolved_debts)){
                if (debt.amount < asset_accounting.reserve) {
                    asset_accounting.reserve -= debt.amount;
                } else {
                    debts_left.add(debt);
                };
            };

            asset_accounting.unsolved_debts := Buffer.toArray(debts_left);
        };

        public func get_available_interests() : Float {
            lending_pool.get_supply_accrued_interests() - Array.foldLeft<DebtEntry, Float>(asset_accounting.unsolved_debts, 0.0, func (acc: Float, debt: DebtEntry) {
                acc + debt.amount;
            });
        };

    };

};