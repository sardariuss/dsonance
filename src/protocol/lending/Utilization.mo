import Debug "mo:base/Debug";
import Float "mo:base/Float";
import Int "mo:base/Int";

import LendingTypes "Types";

module {

    type Utilization = LendingTypes.Utilization;

    public func add_raw_supplied(utilization: Utilization, amount: Nat) : Utilization {
        let raw_supplied = utilization.raw_supplied + Float.fromInt(amount);
        { utilization with raw_supplied; };
    };

    public func remove_raw_supplied(utilization: Utilization, amount: Float) : Utilization {
        let raw_supplied = utilization.raw_supplied - amount;
        if (raw_supplied < 0.0){
            Debug.trap("Cannot remove more than total supplied");
        };
        { utilization with raw_supplied; };
    };

    public func add_raw_borrow(utilization: Utilization, amount: Nat) : Utilization {
        let raw_borrowed = utilization.raw_borrowed + Float.fromInt(amount);
        { utilization with raw_borrowed; };
    };

    public func remove_raw_borrow(utilization: Utilization, amount: Float) : Utilization {
        let raw_borrowed = utilization.raw_borrowed - amount;
        if (raw_borrowed < 0.0){
            Debug.trap("Cannot remove more than total borrowed");
        };
        { utilization with raw_borrowed; };
    };

};