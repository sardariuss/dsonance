import Int "mo:base/Int";
import Float "mo:base/Float";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";

import InterestRateCurve "InterestRateCurve";
import Math "../utils/Math";
import Types "../Types";
import Duration "../duration/Duration";
import LendingTypes "Types";
import Index "Index";

module {

    type Duration = Types.Duration;

    type Index                 = LendingTypes.Index;
    type LendingPoolParameters = LendingTypes.LendingPoolParameters;
    type IndexerState          = LendingTypes.IndexerState;

    public class Indexer({
        parameters: LendingPoolParameters;
        state: IndexerState;
        interest_rate_curve: InterestRateCurve.InterestRateCurve;
    }){

        public func add_raw_supplied({ time: Nat; amount: Nat; }) {
            update_index({ time }); // @todo: not sure if before of after? or just accumulate the interests before?
            state.raw_supplied += amount;
        };

        public func remove_raw_supplied({ time: Nat; amount: Nat; }) {
            update_index({ time });
            if (amount > state.raw_supplied){
                Debug.trap("Cannot remove more than total supplied")
            };
            state.raw_supplied -= amount;
        };

        public func add_raw_borrow({ time: Nat; amount: Nat; }) {
            update_index({ time });
            state.raw_borrowed += Float.fromInt(amount);
        };

        public func remove_raw_borrow({ time: Nat; amount: Float; }) {
            update_index({ time });
            if (amount > state.raw_borrowed){
                Debug.trap("Cannot remove more than total borrowed")
            };
            state.raw_borrowed -= amount;
        };

        public func get_borrow_index({ time: Nat; }) : Index {
            update_index({ time });
            {
                value = state.borrow_index;
                timestamp = time;
            };
        };

        public func compute_utilization() : Float {
            
            if (state.raw_supplied == 0) {
                if (state.raw_borrowed > 0) {
                    // Treat utilization as 100% to maximize borrow rate
                    return 1.0;
                };
                // No supply nor borrowed, consider that the utilization is null
                return 0.0;
            };
            
            state.raw_borrowed / (Float.fromInt(state.raw_supplied) * (1.0 - parameters.reserve_liquidity));
        };

        /// Accrues interest for the past period and updates supply/borrow rates.
        ///
        /// This function should be called at the boundary between two periods, with `time`
        /// being the current timestamp. It finalizes interest accrued over the period
        /// [last_update_timestamp, time] using the supply and borrow rates from the beginning
        /// of that interval.
        ///
        /// Assumptions:
        /// - Supply interest for a given period is always calculated using the rate at the *start* of the period.
        /// - `supply_rate` and `last_update_timestamp` are updated together and should never be stale relative to one another.
        ///
        /// This model ensures consistency and avoids forward-looking rate assumptions.
        func update_index({ time: Nat }) {

            let elapsed_ns : Int = time - state.last_update_timestamp;

            // If the time is before the last update
            if (elapsed_ns < 0) {
                Debug.trap("Cannot update rates: time is before last update");
            } else if (elapsed_ns == 0) {
                Debug.print("Rates are already up to date");
                return;
            };

            // @todo: should the total borrowed be taken into account? what if it is not null?
            if (state.raw_supplied <= 0) {
                Debug.print("No supply, no need to update rates");
                state.last_update_timestamp := time;
                return;
            };

            // Calculate the time period in years
            let elapsed_annual = Duration.toAnnual(Duration.getDuration({ from = state.last_update_timestamp; to = time; }));

            // Calculate utilization ratio
            let utilization = compute_utilization();

            // Get the current rates from the curve
            let borrow_rate = Math.percentage_to_ratio(interest_rate_curve.get_apr(utilization));
            state.supply_rate := borrow_rate * utilization * (1.0 - parameters.protocol_fee);

            // Update the indexes
            state.borrow_index := state.borrow_index * (1.0 + borrow_rate * elapsed_annual);
            state.supply_index := state.supply_index * (1.0 + state.supply_rate * elapsed_annual);
            
            // Accrue the supply interests
            state.supply_accrued_interests += Float.fromInt(state.raw_supplied) * state.supply_rate * elapsed_annual;
            
            // Refresh update timestamp
            state.last_update_timestamp := time;
        };

    };

};