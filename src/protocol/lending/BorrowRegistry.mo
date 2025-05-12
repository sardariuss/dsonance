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

    public type BorrowInput = {
        timestamp: Nat;
        account: Account;
        collateral: Float;
        borrowed: Float;
    };

    public type BorrowPosition = {
        timestamp: Nat;
        account: Account;
        collateral_tx: [TxIndex];
        borrow_tx: [TxIndex];
        collateral: Float;
        borrowed: Float;
        borrow_index: Float;
        repay_tx: [TxIndex]; // @todo: need to limit the number of transfers
        reimburse_tx: [TxIndex]; // @todo: need to limit the number of transfers
    };

    type QueriedBorrowPosition = {
        position: BorrowPosition;
        owed: Float;
        health: Float;
        borrow_duration_ns: Nat;
    };

    // @todo: function to delete positions repaid that are too old
    // @todo: function to transfer the collateral to the user account based on the health factor
    public type BorrowRegister = {
        var total_borrowed: Float;
        var total_collateral: Float;
        map: Map.Map<Account, BorrowPosition>; 
    };

    public class BorrowRegistry({
        register: BorrowRegister;
        ledger: LedgerFacade.LedgerFacade;
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

        // Merge if there is already a position for that account
        public func add_borrow({
            input: BorrowInput;
        }) : async* Result<BorrowPosition, Text> {

            let { timestamp; account; collateral; borrowed; } = input;

            let position = borrow_positionner.new_borrow_position({
                input = input;
                collateral_tx = [];
                borrow_tx = [];
            });

            // Verify the position's LTV
            if (not borrow_positionner.is_valid_ltv({ position; time = timestamp; })) {
                return #err("LTV ratio is above current allowed maximum");
            };

            // Transfer the collateral from the user account
            let collateral_tx = switch(await* ledger.transfer_from({ from = account; amount = Int.abs(Float.toInt(collateral)); })){ // @todo: type check
                case(#err(_)) { return #err("Failed to transfer collateral from the user account"); };
                case(#ok(tx)) { tx; };
            };

            // Transfer the borrow amount to the user account
            let borrow_tx = switch((await* ledger.transfer({ to = account; amount = Int.abs(Float.toInt(borrowed)); })).result){ // @todo: type check
                case(#err(_)) { return #err("Failed to transfer borrow amount to the user account"); };
                case(#ok(tx)) { tx; };
            };

            // @todo: need to revert the collateral transfer if the borrow transfer fails
            
            let updated_position = switch(Map.get(register.map, MapUtils.acchash, account)){
                case(null) {
                    {
                        position with
                        collateral_tx = [collateral_tx];
                        borrow_tx     = [borrow_tx];
                    };
                };
                case(?prev) { 
                    {
                        prev with
                        timestamp     = timestamp;
                        collateral_tx = Array.append(prev.collateral_tx, [collateral_tx]);
                        borrow_tx     = Array.append(prev.borrow_tx, [borrow_tx]);
                        collateral    = prev.collateral + collateral;
                        borrowed      = borrow_positionner.compute_owed({ position = prev; time = timestamp; }) + borrowed;
                        borrow_index  = borrow_positionner.get_borrow_index({ time = timestamp; });
                    };
                };
            };
            Map.set(register.map, MapUtils.acchash, account, updated_position);
            register.total_borrowed += borrowed;
            register.total_collateral += collateral;
            #ok(updated_position);
        };

        // Traps if the slash amount is greater than the position borrow
        // Remove the position if the slash amount is equal to the position borrow
        // Return the updated position otherwise
        public func repay({ account: Account; amount: Nat; time: Nat; }) : async* Result<(), Text> {
            
            let position = switch(Map.get(register.map, MapUtils.acchash, account)){
                case(null) { return #err("No position to slash"); };
                case(?p) { p; };
            };

            // Sanity check
            if (position.borrowed <= 0) {
                return #err("The position has already been fully repaid");
            };

            let owed = Float.ceil(borrow_positionner.compute_owed({ position; time; })); // @todo: check if take the ceiling makes sense
            let repay_amount = Float.min(owed, Float.fromInt(amount));

            // Transfer the repayment from the user
            let repay_tx = switch(await* ledger.transfer_from({ from = account; amount = Int.abs(Float.toInt(repay_amount)); })){
                case(#err(_)) { return #err("Transfer failed"); };
                case(#ok(tx)) { tx; };
            };

            // @todo: the fraction might not be accurate because what is owed will have changed after awaiting the transfer
            let repaid_fraction = repay_amount / owed;
            let difference = repaid_fraction * position.borrowed;

            Map.set(register.map, MapUtils.acchash, account, { position with
                borrowed = position.borrowed - difference;
                repay_tx = Array.append(position.repay_tx, [repay_tx]);
            });
            register.total_borrowed -= difference;

            if (difference == position.borrowed) {
                return await* reimburse_collateral({ account; });
            };

            #ok;
        };

        public func withdraw_collateral({ account: Account; amount: Nat; time: Nat }) : async* Result<(), Text> {

            let position = switch(Map.get(register.map, MapUtils.acchash, account)){
                case(null) { return #err("No position to withdraw from"); };
                case(?p) { p; };
            };

            if (position.collateral <= 0) {
                return #err("The position has no collateral to withdraw");
            };

            let is_healthy = borrow_positionner.is_healthy({
                position = {
                    position with
                    collateral = position.collateral - Float.fromInt(amount);
                };
                time;
            });

            if (not is_healthy) {
                return #err("Cannot withdraw specified collateral amount, position gets unhealthy");
            };

            // Transfer the collateral back to the user
            let reimburse_tx = switch((await* ledger.transfer({ to = account; amount = Int.abs(Float.toInt(position.collateral)); })).result){
                case(#err(_)) { return #err("Failed to transfer collateral back to the user account"); };
                case(#ok(tx)) { tx; };
            };

            Map.set(register.map, MapUtils.acchash, account, { position with 
                collateral = position.collateral - Float.fromInt(amount);
                reimburse_tx = Array.append(position.reimburse_tx, [reimburse_tx]);
            });
            register.total_collateral -= Float.fromInt(amount);

            #ok;
        };

        func reimburse_collateral({ account: Account; }) : async* Result<(), Text> {
            
            let position = switch(Map.get(register.map, MapUtils.acchash, account)){
                case(null) { return #err("No position to reimburse"); };
                case(?p) { p; };
            };

            if (position.collateral <= 0) {
                return #err("The position has no collateral to reimburse");
            };
            if (position.borrowed > 0) {
                return #err("The position has an outstanding borrow");
            };

            // Transfer the collateral back to the user
            let reimburse_tx = switch((await* ledger.transfer({ to = account; amount = Int.abs(Float.toInt(position.collateral)); })).result){
                case(#err(_)) { return #err("Failed to transfer collateral back to the user account"); };
                case(#ok(tx)) { tx; };
            };

            Map.set(register.map, MapUtils.acchash, account, { position with 
                collateral = 0.0;
                reimburse_tx = Array.append(position.reimburse_tx, [reimburse_tx]);
            });
            register.total_collateral -= position.collateral;

            #ok;
        };

        public func query_borrow_position({ account: Account; time: Nat; }) : ?QueriedBorrowPosition {

            switch (Map.get(register.map, MapUtils.acchash, account)){
                case(null) { null; };
                case(?position) {
                    ?{
                        position;
                        health = borrow_positionner.compute_health_factor({ position; time; });
                        borrow_duration_ns = borrow_positionner.borrow_duration_ns({ position; time; });
                        owed = borrow_positionner.compute_owed({ position; time; });
                    };
                };
            };
        };

    };

};