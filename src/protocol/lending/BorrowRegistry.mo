import Nat "mo:base/Nat";
import Map "mo:map/Map";
import Result "mo:base/Result";
import Float "mo:base/Float";

import Types "../Types";
import MapUtils "../utils/Map";
import LedgerFacade "../payement/LedgerFacade";
import BorrowPositionner "BorrowPositionner";
import Index "Index";

module {

    type Account = Types.Account;
    type TxIndex = Types.TxIndex;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type Index = Index.Index;
    
    public type RepaymentArgs = BorrowPositionner.RepaymentArgs;
    public type BorrowPosition = BorrowPositionner.BorrowPosition;

    type QueriedBorrowPosition = {
        position: BorrowPosition;
        owed: Float;
        health: Float;
        //borrow_duration_ns: Nat;
    };

    // @todo: function to delete positions repaid that are too old
    // @todo: function to transfer the collateral to the user account based on the health factor
    public type BorrowRegister = {
        var total_collateral: Nat;
        var total_borrowed: Float;
        map: Map.Map<Account, BorrowPosition>; 
    };

    public class BorrowRegistry({
        register: BorrowRegister;
        supply_ledger: LedgerFacade.LedgerFacade;
        collateral_ledger: LedgerFacade.LedgerFacade;
        borrow_positionner: BorrowPositionner.BorrowPositionner;
    }){

        public func get_total_borrowed(): Float {
            register.total_borrowed;
        };

        public func get_total_collateral(): Nat {
            register.total_collateral;
        };

        public func get_position({ account: Account; }) : ?BorrowPosition {
            Map.get(register.map, MapUtils.acchash, account);
        };

        public func get_positions() : Map.Iter<BorrowPosition> {
            Map.vals(register.map);
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

            let position =  Map.get(register.map, MapUtils.acchash, account);

            // Create or update the borrow position
            var update = borrow_positionner.provide_collateral({ position; account; amount; });
            update := BorrowPositionner.add_tx({ position = update; tx = #COLLATERAL_PROVIDED(tx); });
            Map.set(register.map, MapUtils.acchash, account, update);

            // Update the total collateral
            register.total_collateral += amount;

            #ok;
        };

        public func withdraw_collateral({
            account: Account;
            amount: Nat;
            index: Index;
        }) : async* Result<(), Text> {

            let position = switch(Map.get(register.map, MapUtils.acchash, account)){
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
            Map.set(register.map, MapUtils.acchash, account, update);

            // Update the total collateral
            register.total_collateral -= amount;

            #ok;
        };

        public func borrow({
            account: Account;
            amount: Nat;
            index: Index;
        }) : async* Result<(), Text> {
            
            let position = switch(Map.get(register.map, MapUtils.acchash, account)){
                case(null) { return #err("No position found for account " # debug_show(account)); };
                case(?p) { p; };
            };

            var update = switch(borrow_positionner.borrow_supply({ position; index; amount; })){
                case(#err(err)) { return #err(err); };
                case(#ok(p)) { p; };
            };
            
            // Transfer the borrow amount to the user account
            let tx = switch((await* supply_ledger.transfer({ to = account; amount; })).result){
                case(#err(_)) { return #err("Failed to transfer borrow amount to the user account"); };
                case(#ok(tx)) { tx; };
            };

            // Update the borrow position
            update := BorrowPositionner.add_tx({ position = update; tx = #SUPPLY_BORROWED(tx); });
            Map.set(register.map, MapUtils.acchash, account, update);

            // Update the total borrowed amount
            register.total_borrowed += Float.fromInt(amount);

            #ok;
        };

        public func repay({
            account: Account;
            args: RepaymentArgs;
            index: Index;
        }) : async* Result<(), Text> {
            
            let position = switch(Map.get(register.map, MapUtils.acchash, account)){
                case(null) { return #err("No position found for account " # debug_show(account)); };
                case(?p) { p; };
            };

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
            Map.set(register.map, MapUtils.acchash, account, update);

            register.total_borrowed -= raw_difference;

            #ok;
        };

        public func query_borrow_position({ account: Account; index: Index; }) : ?QueriedBorrowPosition {

            switch (Map.get(register.map, MapUtils.acchash, account)){
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
            let filtered_map = Map.filter<Account, BorrowPosition>(register.map, MapUtils.acchash, func (account: Account, position: BorrowPosition) : Bool {
                not borrow_positionner.is_healthy({ position; index; });
            });
            Map.vals(filtered_map);
        };

    };

};