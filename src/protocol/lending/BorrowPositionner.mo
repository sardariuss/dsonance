import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Float "mo:base/Float";

import Types "../Types";
import Duration "../duration/Duration";

module {

    type Duration = Types.Duration;
    type Account = Types.Account;
    type TxIndex = Types.TxIndex;

    public type BorrowInput = {
        timestamp: Nat;
        account: Account;
        collateral: Float;
        borrowed: Float;
    };

    type BorrowPosition = BorrowInput and {
        collateral_tx: [TxIndex];
        borrow_tx: [TxIndex];
        borrow_index: Float;
        repay_tx: [TxIndex];
        reimburse_tx: [TxIndex];
    };

    public class BorrowPositionner({
        get_borrow_index: ({ time: Nat; }) -> Float;
        get_collateral_price: ({ time: Nat; }) -> Float;
        max_borrow_duration: Duration; // the maximum duration a borrow position can last before it gets liquidated
        max_ltv: Float; // ratio, between 0 and 1, e.g. 0.75
        liquidation_threshold: Float; // ratio, between 0 and 1, e.g. 0.85
    }){

        if (max_ltv > liquidation_threshold){
            Debug.trap("Max LTV exceeds liquidation threshold");
        }; 

        public func new_borrow_position({
            input: BorrowInput;
            collateral_tx: [TxIndex];
            borrow_tx: [TxIndex];
        }) : BorrowPosition {
            {
                input with
                collateral_tx;
                borrow_tx;
                borrow_index = get_borrow_index({ time = input.timestamp; });
                repay_tx = [];
                reimburse_tx = [];
            };
        };

        public func get_borrow_index({
            time: Nat;
        }) : Float {
            get_borrow_index({ time; });
        };

        public func compute_owed({
            position: {
                borrowed: Float;
                borrow_index: Float;
            };
            time: Nat;
        }) : Float {
            position.borrowed * (get_borrow_index({ time; }) / position.borrow_index);
        };

        public func compute_health_factor({
            position: {
                collateral: Float;
                borrowed: Float;
                borrow_index: Float;
            };
            time: Nat;
        }) : Float {
            liquidation_threshold / compute_ltv({ position; time; });
        };

        public func is_healthy({
            position: {
                collateral: Float;
                borrowed: Float;
                borrow_index: Float;
            };
            time: Nat;
        }) : Bool {

            compute_health_factor({ position; time; }) > 1.0;
        };

        public func compute_ltv({
            position: {
                collateral: Float;
                borrowed: Float;
                borrow_index: Float;
            };
            time: Nat;
        }) : Float {

            (position.collateral * get_collateral_price({ time; })) /
            (compute_owed({ position; time; }));
        };

        public func is_valid_ltv({
            position: {
                collateral: Float;
                borrowed: Float;
                borrow_index: Float;
            };
            time: Nat;
        }) : Bool {

            compute_ltv({ position; time; }) < max_ltv;
        };

        public func borrow_duration_ns({
            position: {
                timestamp: Nat;
            };
            time: Nat;
        }) : Nat {
            if (position.timestamp > time) {
                Debug.trap("BorrowPositionner: position timestamp is greater than current time");
            };
            time - position.timestamp;
        };

        public func is_valid_borrow_duration({
            position: {
                timestamp: Nat;
            };
            time: Nat;
        }) : Bool {
            let ratio = Float.fromInt(borrow_duration_ns({ position; time; })) / Float.fromInt(Duration.toTime(max_borrow_duration));
            ratio < 1.0;
        };

    };

};