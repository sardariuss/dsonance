import Nat "mo:base/Nat";
import Map "mo:map/Map";
import Result "mo:base/Result";
import Debug "mo:base/Debug";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Option "mo:base/Option";

import Types "../Types";
import MapUtils "../utils/Map";
import IterUtils "../utils/Iter";
import LedgerFacade "../payement/LedgerFacade";
import BorrowPositionner "BorrowPositionner";
import Index "Index";
import LendingTypes "Types";
import Indexer "Indexer";
import WithdrawalQueue "WithdrawalQueue";
import Utilization "Utilization";

module {

    type Account = Types.Account;
    type TxIndex = Types.TxIndex;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    
    type Repayment       = LendingTypes.Repayment;
    type BorrowPosition        = LendingTypes.BorrowPosition;
    type QueriedBorrowPosition = LendingTypes.QueriedBorrowPosition;
    type Index                 = LendingTypes.Index;
    type BorrowRegister        = LendingTypes.BorrowRegister;
    type Borrow                = LendingTypes.Borrow;
    type ILiquidityPool        = LendingTypes.ILiquidityPool;
    type TotalToLiquidate = {
        raw_borrowed: Float;
        collateral: Nat;
    };

    // @todo: function to delete positions repaid that are too old
    // @todo: function to transfer the collateral to the user account based on the health factor
    public class BorrowRegistry({
        register: BorrowRegister;
        supply_ledger: LedgerFacade.LedgerFacade;
        collateral_ledger: LedgerFacade.LedgerFacade;
        borrow_positionner: BorrowPositionner.BorrowPositionner;
        indexer: Indexer.Indexer;
        supply_withdrawals: WithdrawalQueue.WithdrawalQueue;
        liquidity_pool: ILiquidityPool;
    }){

        public func get_collateral_balance(): Nat {
            register.collateral_balance;
        };

        public func get_position({ account: Account; }) : ?BorrowPosition {
            Map.get(register.borrow_positions, MapUtils.acchash, account);
        };

        public func get_positions() : Map.Iter<BorrowPosition> {
            Map.vals(register.borrow_positions);
        };

        public func supply_collateral({
            account: Account;
            amount: Nat;
        }) : async* Result<(), Text> {

            // Transfer the collateral from the user account
            let tx = switch(await* collateral_ledger.transfer_from({ from = account; amount; })){
                case(#err(_)) { return #err("Failed to transfer collateral from the user account"); };
                case(#ok(tx)) { tx; };
            };

            let position =  Map.get(register.borrow_positions, MapUtils.acchash, account);

            // Create or update the borrow position
            var update = borrow_positionner.provide_collateral({ position; account; amount; });
            update := BorrowPositionner.add_tx({ position = update; tx = #COLLATERAL_PROVIDED(tx); });
            Map.set(register.borrow_positions, MapUtils.acchash, account, update);

            // Update the total collateral
            register.collateral_balance += amount;

            #ok;
        };

        public func withdraw_collateral({
            account: Account;
            amount: Nat;
        }) : async* Result<(), Text> {

            let position = switch(Map.get(register.borrow_positions, MapUtils.acchash, account)){
                case(null) { return #err("No position found for account " # debug_show(account)); };
                case(?p) { p; };
            };

            let index = indexer.get_state().borrow_index;

            // Remove the collateral from the borrow position
            var update = switch(borrow_positionner.withdraw_collateral({ position; amount; index; })){
                case(#err(err)) { return #err(err); };
                case(#ok(p)) { p; };
            };

            // Transfer the collateral to the user account
            let tx = switch((await* collateral_ledger.transfer({ to = account; amount; })).result){
                case(#err(_)) { return #err("Failed to transfer the collateral to the user account"); };
                case(#ok(tx)) { tx; };
            };

            update := BorrowPositionner.add_tx({ position = update; tx = #COLLATERAL_WITHDRAWNED(tx); });
            Map.set(register.borrow_positions, MapUtils.acchash, account, update);

            // Update the total collateral
            register.collateral_balance -= amount;

            #ok;
        };

        public func borrow({
            account: Account;
            amount: Nat;
        }) : async* Result<(), Text> {

            // @todo: should add to a map of <Account, Nat> the amount concurrent borrows that could 
            // increase the utilization ratio more than 1.0

            // Verify the utilization does not exceed the allowed limit
            let utilization = indexer.compute_utilization(Utilization.add_raw_borrow(indexer.get_state().utilization, amount));
            if (utilization.ratio > 1.0) {
                return #err("Utilization of " # debug_show(utilization) # " is greater than 1.0");
            };

            let supply_balance = supply_ledger.get_balance();
            if (supply_balance < amount){
                return #err("Available liquidity " # debug_show(supply_balance) # " is less than the requested amount " # debug_show(amount));
            };
            
            let position = switch(Map.get(register.borrow_positions, MapUtils.acchash, account)){
                case(null) { return #err("No position found for account " # debug_show(account)); };
                case(?p) { p; };
            };

            let index = indexer.get_state().borrow_index;

            var update = switch(borrow_positionner.borrow_supply({ position; index; amount; })){
                case(#err(err)) { return #err(err); };
                case(#ok(p)) { p; };
            };
            
            // Capture the borrow index before initiating the transfer.
            // Note: There may be a slight time drift (~1–2 seconds) between capturing the index
            // and updating the user's position, due to the await on the transfer.
            // This means the position will be recorded with a slightly stale index.
            // In practice, this has negligible impact on accuracy since the interest accrued
            // over a few seconds is minimal. This tradeoff is acceptable to preserve
            // consistency in how interest is calculated and avoid retroactive index shifts.
            
            // Transfer the borrow amount to the user account
            let tx = switch((await* supply_ledger.transfer({ to = account; amount; })).result){
                case(#err(_)) { return #err("Failed to transfer borrow amount to the user account"); };
                case(#ok(tx)) { tx; };
            };

            // Update the borrow position
            update := BorrowPositionner.add_tx({ position = update; tx = #SUPPLY_BORROWED(tx); });
            Map.set(register.borrow_positions, MapUtils.acchash, account, update);
            indexer.add_raw_borrow({ amount; });

            #ok;
        };

        public func repay({
            account: Account;
            repayment: Repayment;
        }) : async* Result<(), Text> {
            
            let position = switch(Map.get(register.borrow_positions, MapUtils.acchash, account)){
                case(null) { return #err("No position found for account " # debug_show(account)); };
                case(?p) { p; };
            };

            let index = indexer.get_state().borrow_index;

            let { amount; raw_repaid; remaining; } = switch(borrow_positionner.repay_supply({ position; index; repayment; })){
                case(#err(err)) { return #err(err); };
                case(#ok(p)) { p; };
            };

            // Transfer the repayment from the user
            let tx = switch(await* supply_ledger.transfer_from({ from = account; amount; })){
                case(#err(_)) { return #err("Transfer failed"); };
                case(#ok(tx)) { tx; };
            };

            // Update the borrow position
            var update = { position with borrow = remaining; };
            update := BorrowPositionner.add_tx({ position = update; tx = #SUPPLY_REPAID(tx); });
            Map.set(register.borrow_positions, MapUtils.acchash, account, update);

            Debug.print("Raw difference after repayment: " # debug_show(raw_repaid));
            indexer.remove_raw_borrow({ amount = raw_repaid });

            // Once a position is repaid, it might allow the unlock withdrawal of supply
            ignore supply_withdrawals.process_pending_withdrawals();

            #ok;
        };

        // @todo: fix partial liquidation, or use full liquidation for now
        /// Liquidate borrow positions if their health factor is below 1.0.
        /// @todo: this function access shall be restricted to the protocol only and called by a timer
        public func check_all_positions_and_liquidate() : async*() {

            let liquidable_positions = get_liquidable_positions();

            let to_liquidate = IterUtils.fold_left(liquidable_positions, { raw_borrowed = 0.0; collateral = 0; }, func (sum: TotalToLiquidate, position: BorrowPosition): TotalToLiquidate {
                {
                    raw_borrowed = sum.raw_borrowed + Option.getMapped(position.borrow, func(borrow: Borrow) : Float { borrow.raw_amount; }, 0.0);
                    collateral = sum.collateral + position.collateral.amount;
                };
            });

            let supply_bought = liquidity_pool.swap_collateral({ amount = to_liquidate.collateral; });

            supply_ledger.add_balance(supply_bought);
            register.collateral_balance -= to_liquidate.collateral;
            indexer.remove_raw_borrow({ amount = to_liquidate.raw_borrowed });

            for (position in liquidable_positions.reset()) {

                Map.set(register.borrow_positions, MapUtils.acchash, position.account, { position with 
                    collateral = { amount = 0; }; 
                    borrow = null;
                });
            };

            // Once positions are liquidated, it might allow the unlock withdrawal of supply
            ignore supply_withdrawals.process_pending_withdrawals();

            // @todo: the total borrowed shall take the slippage into account because otherwise the
            // available total liquidity computation will be wrong (i.e. not reflect the amount actually available)
            //let ratio_sold = Float.fromInt(collateral_sold) / Float.fromInt(collateral_to_sell);
            
//            // Update the positions
//            for (position in liquidable_positions.reset()) {
//
//                ignore lending_pool.slash_borrow({ 
//                    account = position.account;
//                    borrow_amount = position.borrowed * ratio_sold;
//                    collateral_amount = position.collateral * ratio_sold;
//                });
//            };
//
//            let value_sold = Float.fromInt(collateral_sold) * collateral_spot_in_asset();
//            let value_debt = to_liquidate.borrowed * ratio_sold;
//
//            let difference = value_sold - value_debt;
//
//            // @todo: need to take protocol fees
//
//            if (difference >= 0.0) {
//                asset_accounting.reserve += difference;
//            } else {
//                Debug.print("⚠️ Bad debt: liquidation proceeds are insufficient");
//                asset_accounting.unsolved_debts := Array.append(asset_accounting.unsolved_debts, [{ timestamp = time; amount = difference; }]);
//            };
        };

//        public func query_borrow_position({ account: Account; index: Index; }) : ?QueriedBorrowPosition {
//
//            switch (Map.get(register.borrow_positions, MapUtils.acchash, account)){
//                case(null) { null; };
//                case(?position) {
//                    ?{
//                        position;
//                        health = borrow_positionner.compute_health_factor({ position; index; });
//                        //borrow_duration_ns = borrow_positionner.borrow_duration_ns({ position; index; });
//                        owed = 0.0; // @todo: compute the owed amount
//                    };
//                };
//            };
//        };

        public func get_liquidable_positions() : Map.Iter<BorrowPosition> {
            let index = indexer.get_state().borrow_index;
            let filtered_map = Map.filter<Account, BorrowPosition>(register.borrow_positions, MapUtils.acchash, func (account: Account, position: BorrowPosition) : Bool {
                not borrow_positionner.is_healthy({ position; index; });
            });
            Map.vals(filtered_map);
        };

    };

};