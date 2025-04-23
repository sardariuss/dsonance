import Types "Types";
import Duration "duration/Duration";
import Math "utils/Math";

import Float "mo:base/Float";
import Debug "mo:base/Debug";

module {

    type YieldState = Types.YieldState;

    public class Yielder(state: YieldState) {

        public func get_state() : YieldState {
            state;
        };

        public func update_apr({ new_apr: Float; time: Nat; }) {
            accumulate_yield(time);
            state.apr := new_apr;
        };

        public func update_tvl({ new_tvl: Nat; time: Nat; }) {
            accumulate_yield(time);
            state.tvl := new_tvl;
        };

        public func remove_from_earned({to_remove: Nat; time: Nat; }) {
            accumulate_yield(time);
            let diff = state.interest.earned - Float.fromInt(to_remove);
            if (diff < 0) {
                Debug.trap("Cannot remove more than earned");
            };
            state.interest.earned := diff;
        };

        func accumulate_yield(time: Nat) {

            let annual_period = Duration.toAnnual(Duration.getDuration({ from = state.interest.time_last_update; to = time; }));

            state.interest.earned += annual_period * Math.percentageToRatio(state.apr) * Float.fromInt(state.tvl);
            state.interest.time_last_update := time;
        };

    };

};