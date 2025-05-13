import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Float "mo:base/Float";
import Array "mo:base/Array";
import Option "mo:base/Option";

import Types "../Types";
import Duration "../duration/Duration";

module {

    type Duration = Types.Duration;
    type Account = Types.Account;
    type TxIndex = Types.TxIndex;

    type Collateral = {
        amount: Float;
        supplied_tx: [TxIndex];
        reimbursed_tx: [TxIndex];
    };

    type Borrowed = {
        timestamp: Nat;
        index: Float;
        amount: Float;
        borrowed_tx: [TxIndex];
        repaid_tx: [TxIndex];
    };

    public type BorrowPosition = {
        account: Account;
        collateral: Collateral;
        borrowed: ?Borrowed;
    };

    // @todo: check how to handle position duration when collateral is added
    public class BorrowPositionner({
        get_borrow_index: ({ time: Nat; }) -> Float;
        get_collateral_spot_in_asset: ({ time: Nat; }) -> Float;
        //max_borrow_duration: Duration; // the maximum duration a borrow position can last before it gets liquidated
        max_ltv: Float; // ratio, between 0 and 1, e.g. 0.75
        liquidation_threshold: Float; // ratio, between 0 and 1, e.g. 0.85
    }){

        if (max_ltv > liquidation_threshold){
            Debug.trap("Max LTV exceeds liquidation threshold");
        }; 

        public func add_collateral({
            position: ?BorrowPosition;
            account: Account;
            amount: Nat;
            tx: TxIndex;
        }) : BorrowPosition {
            switch(position){
                case(null) {
                    {
                        account;
                        collateral = {
                            amount = Float.fromInt(amount);
                            supplied_tx = [tx];
                            reimbursed_tx = [];
                        };
                        borrowed = null;
                    };
                };
                case(?previous) {
                    if (previous.account != account) {
                        Debug.trap("BorrowPositionner: position account does not match input account");
                    };
                    let collateral = { previous.collateral with 
                        amount = previous.collateral.amount + Float.fromInt(amount);
                        supplied_tx = Array.append(previous.collateral.supplied_tx, [tx]);
                    };
                    { previous with collateral };
                };
            };
        };

        public func remove_collateral({
            position: BorrowPosition;
            amount: Nat;
            tx: TxIndex;
        }) : BorrowPosition {

            // Assumes the removed collateral amount does not lower the health factor more than 1.0

            if (position.collateral.amount < Float.fromInt(amount)) {
                Debug.trap("BorrowPositionner: not enough collateral to remove");
            };

            let collateral = { position.collateral with 
                amount = position.collateral.amount - Float.fromInt(amount);
                reimbursed_tx = Array.append(position.collateral.reimbursed_tx, [tx]);
            };
            { position with collateral };
        };
                
        public func add_borrow({
            position: BorrowPosition;
            timestamp: Nat;
            amount: Float;
            tx: TxIndex;
        }) : BorrowPosition {
            let borrowed = ?(switch(position.borrowed){
                case(null) {
                    {
                        timestamp;
                        index = get_borrow_index({ time = timestamp; });
                        amount;
                        borrowed_tx = [tx];
                        repaid_tx = [];
                    };
                };
                case(?previous_borrowed) {
                    {   
                        previous_borrowed with 
                        timestamp;
                        index = get_borrow_index({ time = timestamp; });
                        amount = compute_owed({ borrowed = previous_borrowed; time = timestamp; }) + amount;
                        borrowed_tx = Array.append(previous_borrowed.borrowed_tx, [tx]);
                    };
                };
            });
            { position with borrowed };
        };

        public func remove_borrow({
            position: BorrowPosition;
            timestamp: Nat;
            amount: Float;
            tx: TxIndex;
        }) : BorrowPosition {

            // Assumes the removed borrow amount does not lower the health factor more than 1.0
            let borrowed = switch(position.borrowed){
                case(null) { Debug.trap("BorrowPositionner: no borrow to remove"); };
                case(?b) { b; };
            };
                
            if (borrowed.amount < amount) {
                Debug.trap("BorrowPositionner: not enough borrowed amount to remove");
            };

            { 
                position with borrowed = ?{ 
                    borrowed with 
                    timestamp;
                    index = get_borrow_index({ time = timestamp; });
                    amount = compute_owed({ borrowed; time = timestamp; }) - amount;
                    repaid_tx = Array.append(borrowed.repaid_tx, [tx]);
                };
            };
        };

        public func compute_owed({
            borrowed: Borrowed;
            time: Nat;
        }) : Float {
            borrowed.amount * (get_borrow_index({ time; }) / borrowed.index);
        };

        public func compute_health_factor({
            position: BorrowPosition;
            time: Nat;
        }) : Float {
            liquidation_threshold / compute_ltv({ position; time; });
        };

        public func is_healthy({
            position: BorrowPosition;
            time: Nat;
        }) : Bool {
            compute_health_factor({ position; time; }) > 1.0;
        };

        public func compute_ltv({
            position: BorrowPosition;
            time: Nat;
        }) : Float {
            let borrowed = Option.get(position.borrowed, empty_borrowed()); // @todo: check if no side effects
            compute_owed({ borrowed; time; }) / (position.collateral.amount * get_collateral_spot_in_asset({ time; }));
        };

        public func is_inferior_max_ltv({
            position: BorrowPosition;
            time: Nat;
        }) : Bool {
            compute_ltv({ position; time; }) < max_ltv;
        };

    };

    func empty_borrowed() : Borrowed {
        {
            timestamp = 0;
            index = 0.0;
            amount = 0.0;
            borrowed_tx = [];
            repaid_tx = [];
        };
    };

};