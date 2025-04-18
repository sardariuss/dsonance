import Types "Types";
import Duration "duration/Duration";

import Debug "mo:base/Debug";
import Float "mo:base/Float";

module {

    type YieldState = Types.YieldState;

    public class Yielder(state: YieldState) {

        public func update_apr({ new_apr: Float; time: Nat; }) {
            accumulate_yield(time);
            state.apr := new_apr;
        };

        public func update_tvl({ new_tvl: Nat; time: Nat; }) {
            accumulate_yield(time);
            state.tvl := new_tvl;
        };

        func accumulate_yield(time: Nat) {

            let period : Int = time - state.interest.time_last_update;

            if (period < 0) {
                Debug.trap("Cannot accumulate yield on a negative period");
            };

            state.interest.earned += (Float.fromInt(period) / Float.fromInt(Duration.NS_IN_YEAR)) * state.apr * 100.0 * Float.fromInt(state.tvl);
            state.interest.time_last_update := time;
        };

    };

};