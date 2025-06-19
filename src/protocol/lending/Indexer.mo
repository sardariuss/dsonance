import Int                "mo:base/Int";
import Float              "mo:base/Float";
import Nat                "mo:base/Nat";
import Debug              "mo:base/Debug";
import Result             "mo:base/Result";
import Option             "mo:base/Option";
import Buffer             "mo:base/Buffer";

import InterestRateCurve  "InterestRateCurve";
import Math               "../utils/Math";
import Types              "../Types";
import Duration           "../duration/Duration";
import LendingTypes       "Types";
import Clock              "../utils/Clock";
import UtilizationUpdater "UtilizationUpdater";

module {

    type Duration = Types.Duration;
    type Result<Ok, Err> = Result.Result<Ok, Err>;

    type Index                 = LendingTypes.Index;
    type IndexerParameters     = LendingTypes.IndexerParameters;
    type IndexerState          = LendingTypes.IndexerState;
    type SIndexerState         = LendingTypes.SIndexerState;
    type Utilization           = LendingTypes.Utilization;
    
    type Observer = (SIndexerState) -> ();

    public class Indexer({
        parameters: IndexerParameters;
        state: IndexerState;
        interest_rate_curve: InterestRateCurve.InterestRateCurve;
        clock: Clock.IClock;
        utilization_updater: UtilizationUpdater.UtilizationUpdater;
    }){

        let observers = Buffer.Buffer<Observer>(0);

        public func add_observer(observer: Observer) {
            observers.add(observer);
        };

        public func get_state() : SIndexerState {
            update_state(null);
            {
                utilization = state.utilization;
                supply_index = { value = state.supply_index; timestamp = state.last_update_timestamp };
                borrow_index = { value = state.borrow_index; timestamp = state.last_update_timestamp };
                last_update_timestamp = state.last_update_timestamp;
                borrow_rate = state.borrow_rate;
                supply_rate = state.supply_rate;
                accrued_interests = {
                    fees = state.accrued_interests.fees;
                    supply = state.accrued_interests.supply;
                };
            };
        };

        public func add_raw_supplied({ amount: Nat; }) {
            let utilization = switch(utilization_updater.add_raw_supplied(state.utilization, amount)){
                case(#err(err)) { Debug.trap(err); };
                case(#ok(u)){ u; };
            };
            update_state(?utilization);
        };

        public func remove_raw_supplied({ amount: Float; }) {
            let utilization = switch(utilization_updater.remove_raw_supplied(state.utilization, amount)){
                case(#err(err)) { Debug.trap(err); };
                case(#ok(u)){ u; };
            };
            update_state(?utilization);
        };

        public func add_raw_borrow({ amount: Nat; }) {
            let utilization = switch(utilization_updater.add_raw_borrow(state.utilization, amount)){
                case(#err(err)) { Debug.trap(err); };
                case(#ok(u)){ u; };
            };
            update_state(?utilization);
        };

        public func remove_raw_borrow({ amount: Float; }) {
            let utilization = switch(utilization_updater.remove_raw_borrow(state.utilization, amount)){
                case(#err(err)) { Debug.trap(err); };
                case(#ok(u)){ u; };
            };
            update_state(?utilization);
        };

        public func take_supply_interests({ share: Float; minimum: Int; }) : Result<Int, Text> {
            update_state(null);
            // Make sure the share is normalized
            if (not Math.is_normalized(share)) {
                return #err("Invalid interest share");
            };
            // Make sure the interests is above the minimum
            let interests_amount = Float.toInt(Float.max(Float.fromInt(minimum), state.accrued_interests.supply * share));
            // Remove the interests from the supply
            state.accrued_interests := {
                fees = state.accrued_interests.fees;
                supply = state.accrued_interests.supply - Float.fromInt(interests_amount);
            };
            // Return the amount
            #ok(interests_amount);
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
        public func update_state(utilization: ?Utilization) {

            let time = clock.get_time();
            let elapsed_ns : Int = time - state.last_update_timestamp;

            // If the time is before the last update
            if (elapsed_ns < 0) {
                Debug.trap("Cannot update state: time is before last update");
            };
            
            let previous_state = state;
            var state_updated = false;

            Option.iterate(utilization, func (new_utilization: Utilization) {
                // Update the utilization
                state.utilization := new_utilization;
                // Get the current rates from the curve
                state.borrow_rate := interest_rate_curve.get_apr(state.utilization.ratio);
                state.supply_rate := state.borrow_rate * state.utilization.ratio;
                // Need to notify the observers
                state_updated := true;
            });

            if (elapsed_ns > 0) {
                // Calculate the time period in years
                let elapsed_annual = Duration.toAnnual(Duration.getDuration({ from = state.last_update_timestamp; to = time; }));
                // Update the indexes
                state.borrow_index := state.borrow_index * (1.0 + state.borrow_rate * elapsed_annual);
                state.supply_index := state.supply_index * (1.0 + state.supply_rate * elapsed_annual);
                // Accrue the supply interests up to this date using the previous state up to this date!
                accrue_interests({ state = previous_state; elapsed_annual; });
                // Refresh update timestamp
                state.last_update_timestamp := time;
                // Need to notify the observers
                state_updated := true;
            };

            // Notify the observers if the state has been updated
            if (state_updated) {
                let new_state = get_state();
                for (observer in observers.vals()) {
                    observer(new_state);
                };
            };
        };

        func accrue_interests({state: IndexerState; elapsed_annual: Float}) {
            let interests = state.utilization.raw_supplied * state.supply_rate * elapsed_annual;
            state.accrued_interests := {
                fees = state.accrued_interests.fees + interests * parameters.lending_fee_ratio;
                supply = state.accrued_interests.supply + interests * (1.0 - parameters.lending_fee_ratio);
            };
        };

    };

};