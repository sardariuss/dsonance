import Nat "mo:base/Nat";
import Map "mo:map/Map";
import Array "mo:base/Array";
import Result "mo:base/Result";
import Int "mo:base/Int";
import Float "mo:base/Float";

import Types "../Types";
import MapUtils "../utils/Map";
import LedgerFacade "../payement/LedgerFacade";
import BorrowPositionner "BorrowPositionner";

module {

    type Account = Types.Account;
    type TxIndex = Types.TxIndex;
    type Result<Ok, Err> = Result.Result<Ok, Err>;

    public type BorrowPosition = {
        account: Account;
        collateral: {
            amount: Float;
            supplied_tx: [TxIndex];
            reimbursed_tx: [TxIndex];
        };
        borrowed: ?{
            timestamp: Nat;
            index: Float;
            amount: Float;
            borrowed_tx: [TxIndex];
            repaid_tx: [TxIndex];
        };
    };

    type QueriedBorrowPosition = {
        position: BorrowPosition;
        owed: Float;
        health: Float;
        //borrow_duration_ns: Nat;
    };

    // @todo: function to delete positions repaid that are too old
    // @todo: function to transfer the collateral to the user account based on the health factor
    public type BorrowRegister = {
        var total_borrowed: Float; // @todo: why not Nat?
        var total_collateral: Float; // @todo: why not Nat?
        map: Map.Map<Account, BorrowPosition>; 
    };

    public class BorrowRegistry({
        register: BorrowRegister;
        supply_ledger: LedgerFacade.LedgerFacade;
        collateral_ledger: LedgerFacade.LedgerFacade;
        borrow_positionner: BorrowPositionner.BorrowPositionner;
    }){

        public func get_total_borrowed(): Float{
            register.total_borrowed;
        };

        public func get_total_collateral(): Float{
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

            // Create or update the borrow position
            let position = borrow_positionner.add_collateral({
                position = Map.get(register.map, MapUtils.acchash, account);
                account;
                amount;
                tx;
            });
            Map.set(register.map, MapUtils.acchash, account, position);

            // Update the total collateral
            register.total_collateral += Float.fromInt(amount);

            #ok;
        };

        public func withdraw_collateral({
            account: Account;
            amount: Nat;
            time: Nat;
        }) : async* Result<(), Text> {

            let position = switch(Map.get(register.map, MapUtils.acchash, account)){
                case(null) { return #err("No position to withdraw from"); };
                case(?p) { p; };
            };

            // Sanity check
            if (position.collateral.amount < Float.fromInt(amount)) {
                return #err("The position has not enough collateral to withdraw");
            };

            // Check if the position will be healthy after removing the collateral
            let preview = borrow_positionner.remove_collateral({
                position;
                amount;
                tx = 0; // Dummy tx, not used
            });
            if (not borrow_positionner.is_healthy({ position = preview; time; })) {
                return #err("Cannot withdraw specified collateral amount, position gets unhealthy");
            };

            // Transfer the collateral to the user account
            let tx = switch((await* collateral_ledger.transfer({ to = account; amount; })).result){
                case(#err(_)) { return #err("Failed to transfer the collateral to the user account"); };
                case(#ok(tx)) { tx; };
            };

            // Update the borrow position
            let update = borrow_positionner.remove_collateral({
                position;
                amount;
                tx;
            });
            Map.set(register.map, MapUtils.acchash, account, update);

            // Update the total collateral
            register.total_collateral -= Float.fromInt(amount);

            #ok;
        };

        public func borrow({
            account: Account;
            amount: Nat;
            timestamp: Nat;
        }) : async* Result<(), Text> {
            
            let position = switch(Map.get(register.map, MapUtils.acchash, account)){
                case(null) { return #err("No collateral position found for account"); };
                case(?p) { p; };
            };

            // Check if the position does not reach the maximum LTV ratio
            let preview = borrow_positionner.add_borrow({
                position;
                timestamp;
                amount = Float.fromInt(amount);
                tx = 0; // Dummy tx, not used
            });
            if (not borrow_positionner.is_inferior_max_ltv({ position = preview; time = timestamp; })) {
                return #err("LTV ratio is above current allowed maximum");
            };

            // Transfer the borrow amount to the user account
            let tx = switch((await* supply_ledger.transfer({ to = account; amount; })).result){
                case(#err(_)) { return #err("Failed to transfer borrow amount to the user account"); };
                case(#ok(tx)) { tx; };
            };

            // Update the borrow position
            let update = borrow_positionner.add_borrow({
                position;
                timestamp;
                amount = Float.fromInt(amount);
                tx;
            });
            Map.set(register.map, MapUtils.acchash, account, update);

            // Update the total borrowed amount
            register.total_borrowed += Float.fromInt(amount);

            #ok;
        };

        public func repay({
            account: Account;
            amount: Nat;
            time: Nat;
        }) : async* Result<(), Text> {
            
            let position = switch(Map.get(register.map, MapUtils.acchash, account)){
                case(null) { return #err("No position to repay"); };
                case(?p) { p; };
            };

            let owed = Float.ceil(borrow_positionner.compute_owed({ position; time; }));
            let repay_amount = Float.min(owed, Float.fromInt(amount));

            // Transfer the repayment from the user
            let repay_tx = switch(await* supply_ledger.transfer_from({ from = account; amount = Int.abs(Float.toInt(repay_amount)); })){
                case(#err(_)) { return #err("Transfer failed"); };
                case(#ok(tx)) { tx; };
            };

            let repaid_fraction = repay_amount / owed;
            let difference = repaid_fraction * position.borrowed;

            Map.set(register.map, MapUtils.acchash, account, { position with
                borrowed = position.borrowed - difference;
                repay_tx = Array.append(position.repay_tx, [repay_tx]);
            });
            register.total_borrowed -= difference;

            #ok;
        };

        public func query_borrow_position({ account: Account; time: Nat; }) : ?QueriedBorrowPosition {

            switch (Map.get(register.map, MapUtils.acchash, account)){
                case(null) { null; };
                case(?position) {
                    ?{
                        position;
                        health = borrow_positionner.compute_health_factor({ position; time; });
                        //borrow_duration_ns = borrow_positionner.borrow_duration_ns({ position; time; });
                        owed = borrow_positionner.compute_owed({ position; time; });
                    };
                };
            };
        };

        public func get_liquidable_positions({ time: Nat; }) : Map.Iter<BorrowPosition> {
            let filtered_map = Map.filter<Account, BorrowPosition>(register.map, MapUtils.acchash, func (account: Account, position: BorrowPosition) : Bool {
                // Take unhealthy positions with positive borrowed amount
                position.borrowed > 0.0 and (not borrow_positionner.is_healthy({ position; time; }));
            });
            Map.vals(filtered_map);
        };

    };

};