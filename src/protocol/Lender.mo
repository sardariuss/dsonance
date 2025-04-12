import Duration "duration/Duration";

import Debug "mo:base/Debug";
import Float "mo:base/Float";

module {

    public type LenderInfo = {
        var tvl: Nat;
        var rate_per_year: Float;
        interest: {
            var earned: Float;
            var last_update: Nat;
        };
    };

    public class Lender(info: LenderInfo) {

        public func update_rate({ new_rate_per_year: Float; time: Nat; }) : LenderInfo {
            accumulate_yield(time);
            info.rate_per_year := new_rate_per_year;
            info;
        };

        public func add_lend_amount({ amount: Nat; time: Nat; }) : LenderInfo {
            accumulate_yield(time);
            info.tvl += amount;
            info;
        };

        public func remove_lend_amount({ amount: Nat; time: Nat; }) : LenderInfo {
            accumulate_yield(time);
            info.tvl -= amount;
            info;
        };

        func accumulate_yield(time: Nat) {

            let period : Int = time - info.interest.last_update;

            if (period < 0) {
                Debug.trap("Cannot accumulate yield on a negative period");
            };

            info.interest.earned += (Float.fromInt(period) / Float.fromInt(Duration.NS_IN_YEAR)) * info.rate_per_year * Float.fromInt(info.tvl);
            info.interest.last_update := time;
        };

    };

};