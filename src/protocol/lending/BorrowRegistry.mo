import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Map "mo:map/Map";
import Array "mo:base/Array";

import Types "../Types";
import MapUtils "../utils/Map";

module {

    type Account = Types.Account;
    type TxIndex = Types.TxIndex;

    public type BorrowInput = {
        timestamp: Nat;
        account: Account;
        collateral_tx: TxIndex;
        borrow_tx: TxIndex;
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
    };

    public type BorrowRegister = {
        var total_borrowed: Float;
        var total_collateral: Float;
        map: Map.Map<Account, BorrowPosition>; 
    };

    public func compute_owed({
        position: BorrowPosition;
        current_index: Float;
    }) : Float {
        position.borrowed * (current_index / position.borrow_index);
    };

    public class BorrowRegistry(register: BorrowRegister){

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
            current_index: Float;
        }) : BorrowPosition {
            
            let updated_position = switch(Map.get(register.map, MapUtils.acchash, input.account)){
                case(null) {
                    {
                        input with
                        collateral_tx = [input.collateral_tx];
                        borrow_tx     = [input.borrow_tx];
                        borrow_index  = current_index;
                    };
                };
                case(?position) { 
                    {
                        position with
                        timestamp     = input.timestamp;
                        collateral_tx = Array.append(position.collateral_tx, [input.collateral_tx]);
                        borrow_tx     = Array.append(position.borrow_tx, [input.borrow_tx]);
                        collateral    = position.collateral + input.collateral;
                        borrowed      = compute_owed({ position; current_index; }) + input.borrowed;
                        borrow_index  = current_index;
                    };
                };
            };
            Map.set(register.map, MapUtils.acchash, input.account, updated_position);
            register.total_borrowed += input.borrowed;
            register.total_collateral += input.collateral;
            updated_position;
        };

        // Traps if the slash amount is greater than the position borrow
        // Remove the position if the slash amount is equal to the position borrow
        // Return the updated position otherwise
        public func slash_borrow({ account: Account; borrow_amount: Float; collateral_amount: Float; }) : ?BorrowPosition {
            
            let position = switch(Map.get(register.map, MapUtils.acchash, account)){
                case(null) { Debug.trap("No position to slash"); };
                case(?position) { position; };
            };

            let borrow_diff = position.borrowed - borrow_amount;
            let collateral_diff = position.collateral - collateral_amount;

            // @todo: is this really the behavior wanted?
            if (borrow_diff < 0) {
                Debug.trap("Insufficient borrow to slash");
            };
            if (collateral_diff < 0) {
                Debug.trap("Insufficient collateral to slash");
            };

            if (borrow_diff == 0){
                Debug.print("Borrow slashed completely");
                register.total_borrowed -= position.borrowed;
                register.total_collateral -= position.collateral;
                Map.delete(register.map, MapUtils.acchash, account);
                return null;
            };
            
            register.total_borrowed -= borrow_amount;
            register.total_collateral -= collateral_amount;
            let updated_position = { position with borrowed = borrow_diff; collateral = collateral_diff; };
            Map.set(register.map, MapUtils.acchash, account, updated_position);
            ?updated_position;
        };
    };

};