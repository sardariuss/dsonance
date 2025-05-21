import Nat "mo:base/Nat";
import Map "mo:map/Map";
import Result "mo:base/Result";

import Types "../Types";
import MapUtils "../utils/Map";
import LedgerFacade "../payement/LedgerFacade";
import BorrowPositionner "BorrowPositionner";
import Index "Index";
import LendingTypes "Types";
import Indexer "Indexer";
import WithdrawalQueue "WithdrawalQueue";

module {

    type Account = Types.Account;
    type TxIndex = Types.TxIndex;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    
    type RepaymentArgs         = LendingTypes.RepaymentArgs;
    type BorrowPosition        = LendingTypes.BorrowPosition;
    type QueriedBorrowPosition = LendingTypes.QueriedBorrowPosition;
    type Index                 = LendingTypes.Index;
    type BorrowRegister        = LendingTypes.BorrowRegister;

    // @todo: function to delete positions repaid that are too old
    // @todo: function to transfer the collateral to the user account based on the health factor
    public class BorrowRegistry({
        register: BorrowRegister;
        supply_ledger: LedgerFacade.LedgerFacade;
        collateral_ledger: LedgerFacade.LedgerFacade;
        borrow_positionner: BorrowPositionner.BorrowPositionner;
        indexer: Indexer.Indexer;
        supply_withdrawals: WithdrawalQueue.WithdrawalQueue;
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
            index: Index;
        }) : async* Result<(), Text> {

            let position = switch(Map.get(register.borrow_positions, MapUtils.acchash, account)){
                case(null) { return #err("No position found for account " # debug_show(account)); };
                case(?p) { p; };
            };

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

            // @todo: should add to a map of <Account, Nat> the amount borrowed to prevent
            // borrowing more than utilization allows (or liquidity?)

            // Verify the utilization does not exceed the allowed limit
            //let utilization = indexer.compute_utilization({ borrow_to_add = Float.fromInt(amount); });
            //if (utilization > 1.0) {
                //return #err("Utilization of " # debug_show(utilization) # " is greater than 1.0");
            //};

            let supply_balance = supply_ledger.get_balance();
            if (supply_balance < amount){
                return #err("Available liquidity " # debug_show(supply_balance) # " is less than the requested amount " # debug_show(amount));
            };
            
            let position = switch(Map.get(register.borrow_positions, MapUtils.acchash, account)){
                case(null) { return #err("No position found for account " # debug_show(account)); };
                case(?p) { p; };
            };

            let index = indexer.get_borrow_index();

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

            // Update the total supply balance
            register.supply_balance -= amount;

            #ok;
        };

        public func repay({
            account: Account;
            args: RepaymentArgs;
        }) : async* Result<(), Text> {
            
            let position = switch(Map.get(register.borrow_positions, MapUtils.acchash, account)){
                case(null) { return #err("No position found for account " # debug_show(account)); };
                case(?p) { p; };
            };

            let index = indexer.get_borrow_index();

            let { amount; remaining; raw_difference; } = switch(borrow_positionner.repay_supply({ position; index; args; })){
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
            indexer.remove_raw_borrow({ amount = raw_difference });

            // Update the total supply balance
            register.supply_balance += amount;

            // Once a position is repaid, it might allow the unlock withdrawal of supply
            ignore supply_withdrawals.process_pending_withdrawals();

            #ok;
        };

        public func query_borrow_position({ account: Account; index: Index; }) : ?QueriedBorrowPosition {

            switch (Map.get(register.borrow_positions, MapUtils.acchash, account)){
                case(null) { null; };
                case(?position) {
                    ?{
                        position;
                        health = borrow_positionner.compute_health_factor({ position; index; });
                        //borrow_duration_ns = borrow_positionner.borrow_duration_ns({ position; index; });
                        owed = 0.0; // @todo: compute the owed amount
                    };
                };
            };
        };

        public func get_liquidable_positions({ index: Index; }) : Map.Iter<BorrowPosition> {
            let filtered_map = Map.filter<Account, BorrowPosition>(register.borrow_positions, MapUtils.acchash, func (account: Account, position: BorrowPosition) : Bool {
                not borrow_positionner.is_healthy({ position; index; });
            });
            Map.vals(filtered_map);
        };

    };

};