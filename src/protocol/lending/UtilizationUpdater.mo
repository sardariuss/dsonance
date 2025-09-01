import Float        "mo:base/Float";
import Result       "mo:base/Result";
import Debug        "mo:base/Debug";

import LendingTypes "Types";

module {

    let EPSILON = 1e-6; // TODO: review if this epsilon is appropriate for the use case

    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type Utilization     = LendingTypes.Utilization;

    public func add_raw_supplied(utilization: Utilization, amount: Nat) : Utilization {
        let raw_supplied = utilization.raw_supplied + Float.fromInt(amount);
        let ratio = compute_ratio({ raw_supplied; raw_borrowed = utilization.raw_borrowed; });
        { utilization with raw_supplied; ratio };
    };

    public func remove_raw_supplied(utilization: Utilization, amount: Float) : Utilization {
        // Clamp to zero instead of erroring
        let raw_supplied = Float.max(utilization.raw_supplied - amount, 0.0);
        let ratio = compute_ratio({ raw_supplied; raw_borrowed = utilization.raw_borrowed; });
        { utilization with raw_supplied; ratio };
    };

    public func add_raw_borrow(utilization: Utilization, amount: Nat) : Result<Utilization, Text> {
        var raw_borrowed = utilization.raw_borrowed + Float.fromInt(amount);

        // Mathematical constraint: cannot borrow more than total supplied + EPSILON
        if (raw_borrowed - utilization.raw_supplied > EPSILON) {
            return #err("Cannot borrow more than total supplied: " # debug_show(raw_borrowed) # " > " # debug_show(utilization.raw_supplied));
        };
        
        // Clamp tiny overshoot due to floating point
        raw_borrowed := Float.min(raw_borrowed, utilization.raw_supplied);

        let ratio = compute_ratio({ raw_supplied = utilization.raw_supplied; raw_borrowed; });
        #ok({ utilization with raw_borrowed = raw_borrowed; ratio });
    };

    public func remove_raw_borrow(utilization: Utilization, amount: Float) : Utilization {
        // Clamp to zero instead of erroring
        let raw_borrowed = Float.max(utilization.raw_borrowed - amount, 0.0);
        let ratio = compute_ratio({ raw_supplied = utilization.raw_supplied; raw_borrowed });
        { utilization with raw_borrowed; ratio };
    };

    public func compute_ratio({
        raw_supplied: Float;
        raw_borrowed: Float;
    }) : Float {

        // Invariant checks: these should *never* be violated
        if (raw_supplied < -EPSILON or raw_borrowed < -EPSILON) {
            Debug.trap("Invariant broken: negative raw_supplied or raw_borrowed");
        };

        if (raw_borrowed > raw_supplied + EPSILON) {
            Debug.trap("Invariant broken: borrowed exceeds supplied");
        };

        // Handle the zero-supply case
        if (raw_supplied == 0.0) {
            return if (raw_borrowed > 0.0) { 1.0 } else { 0.0 };
        };

        // Pure mathematical utilization ratio
        raw_borrowed / raw_supplied;
    };

};