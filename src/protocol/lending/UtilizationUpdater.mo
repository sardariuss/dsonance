import Float        "mo:base/Float";
import Result       "mo:base/Result";

import LendingTypes "Types";

module {

    type Result<Ok, Err>       = Result.Result<Ok, Err>;
    type Utilization           = LendingTypes.Utilization;
    type UtilizationParameters = LendingTypes.UtilizationParameters;

    public class UtilizationUpdater({
        parameters: UtilizationParameters;
    }){

        public func add_raw_supplied(utilization: Utilization, amount: Nat) : Result<Utilization, Text> {
            let raw_supplied = utilization.raw_supplied + Float.fromInt(amount);
            update_ratio({ utilization with raw_supplied });
        };

        public func remove_raw_supplied(utilization: Utilization, amount: Float) : Result<Utilization, Text> {
            let raw_supplied = utilization.raw_supplied - amount;
            if (raw_supplied < 0.0){
                return #err("Cannot remove more than total supplied");
            };
            update_ratio({ utilization with raw_supplied; });
        };

        public func add_raw_borrow(utilization: Utilization, amount: Nat) : Result<Utilization, Text> {
            let raw_borrowed = utilization.raw_borrowed + Float.fromInt(amount);
            update_ratio({ utilization with raw_borrowed; });
        };

        public func remove_raw_borrow(utilization: Utilization, amount: Float) : Result<Utilization, Text> {
            let raw_borrowed = utilization.raw_borrowed - amount;
            if (raw_borrowed < 0.0){
                return #err("Cannot remove more than total borrowed");
            };
            update_ratio({ utilization with raw_borrowed; });
        };

        public func compute_utilization_ratio({
            raw_supplied: Float;
            raw_borrowed: Float;
        }) : Result<Float, Text> {

            if (raw_supplied < 0.0) {
                return #err("Logic error: raw supplied cannot be negative");
            };
            if (raw_borrowed < 0.0) {
                return #err("Logic error: raw borrowed cannot be negative");
            };

            let available = raw_supplied * (1.0 - parameters.reserve_liquidity);
            if (available == 0) {
                return if (raw_borrowed > 0) { #ok(1.0) } else { #ok(0.0) };
            };
            
            #ok(Float.min(1.0, raw_borrowed / available));
        };

        func update_ratio(utilization: Utilization) : Result<Utilization, Text> {
            let ratio = switch(compute_utilization_ratio(utilization)){
                case(#err(err)) { return #err(err); };
                case(#ok(r)) { r; };
            };
            #ok({ utilization with ratio; });
        };
    };

};