import Int                "mo:base/Int";
import Float              "mo:base/Float";
import Nat                "mo:base/Nat";
import Debug              "mo:base/Debug";
import Result             "mo:base/Result";
import Buffer             "mo:base/Buffer";

import LendingTypes       "Types";
import UtilizationUpdater "UtilizationUpdater";
import InterestRateCurve  "InterestRateCurve";
import Types              "../Types";
import Duration           "../duration/Duration";
import Timeline           "../utils/Timeline";

module {

    type Duration        = Types.Duration;
    type Result<Ok, Err> = Result.Result<Ok, Err>;

    type Index                 = LendingTypes.Index;
    type IndexerParameters     = LendingTypes.IndexerParameters;
    type LendingIndex          = LendingTypes.LendingIndex;
    type Utilization           = LendingTypes.Utilization;
    
    type Observer = (LendingIndex) -> ();

    public class Indexer({
        index: Timeline.Timeline<LendingIndex>;
        parameters: IndexerParameters;
        interest_rate_curve: InterestRateCurve.InterestRateCurve;
    }){

        let observers = Buffer.Buffer<Observer>(0);

        public func add_observer(observer: Observer) {
            observers.add(observer);
        };

        public func get_parameters() : IndexerParameters {
            parameters;
        };

        public func get_index(time: Nat) : LendingIndex {
            update(null, time);
            Timeline.current(index);
        };

        public func add_raw_supplied({ amount: Nat; time: Nat; }) {
            let current_index = Timeline.current(index);
            let utilization = UtilizationUpdater.add_raw_supplied(current_index.utilization, amount);
            update(?utilization, time);
        };

        public func remove_raw_supplied({ amount: Float; time: Nat; }) {
            let current_index = Timeline.current(index);
            let utilization = UtilizationUpdater.remove_raw_supplied(current_index.utilization, amount);
            update(?utilization, time);
        };

        public func add_raw_borrow({ amount: Nat; time: Nat; }) {
            let current_index = Timeline.current(index);
            let utilization = switch(UtilizationUpdater.add_raw_borrow(current_index.utilization, amount)){
                case(#err(err)) { Debug.trap(err); };
                case(#ok(u)){ u; };
            };
            update(?utilization, time);
        };

        public func remove_raw_borrow({ amount: Float; time: Nat; }) {
            let current_index = Timeline.current(index);
            let utilization = UtilizationUpdater.remove_raw_borrow(current_index.utilization, amount);
            update(?utilization, time);
        };

        public func take_borrow_interests({ amount: Float; time: Nat }) {
            update(null, time);
            let current_index = Timeline.current(index);
            let accrued_interests = current_index.accrued_interests;
            let clamped_amount = Float.min(amount, accrued_interests.borrow);
            // Remove the interests from the borrow
            let new_index = { current_index with
                accrued_interests = { accrued_interests with
                    borrow = accrued_interests.borrow - clamped_amount;
                };
            };
            Timeline.insert(index, time, new_index);
        };

        public func take_supply_interests({ amount: Float; time: Nat; }) : Result<(), Text> {
            update(null, time);
            let current_index = Timeline.current(index);
            let accrued_interests = current_index.accrued_interests;
            // Make sure the amount is not greater than available supply interests
            if (amount > accrued_interests.supply) {
                return #err("Amount " # debug_show(amount) # " is greater than available supply interests " # debug_show(accrued_interests.supply));
            };
            // Remove the interests from the supply
            let new_index = { current_index with
                accrued_interests = { accrued_interests with
                    supply = accrued_interests.supply - amount;
                };
            };
            Timeline.insert(index, time, new_index);
            #ok;
        };

        public func update(new_utilization: ?Utilization, time: Nat) {

            let current_index = Timeline.current(index);

            // Update the state with the new utilization and interest rates
            let new_index = update_index({
                state = current_index;
                parameters;
                interest_rate_curve;
                time;
                new_utilization;
            });

            // Insert the new index into the timeline
            Timeline.insert(index, time, new_index);

            // Notify observers of the new state
            for (observer in observers.vals()) {
                observer(new_index);
            };
        };

    };

    /// Accrues interest for the past period and updates supply/borrow rates.
    ///
    /// This function should be called at the boundary between two periods, with `time`
    /// being the current timestamp. It finalizes interest accrued over the period
    /// [timestamp, time] using the supply and borrow rates from the beginning
    /// of that interval.
    ///
    /// Assumptions:
    /// - Supply interest for a given period is always calculated using the rate at the *start* of the period.
    /// - `supply_rate` and `timestamp` are updated together and should never be stale relative to one another.
    ///
    /// This model ensures consistency and avoids forward-looking rate assumptions.
    public func update_index({
        state: LendingIndex;
        parameters: IndexerParameters;
        interest_rate_curve: InterestRateCurve.InterestRateCurve;
        time: Nat;
        new_utilization: ?Utilization;
    }) : LendingIndex {

        let new_state = switch(new_utilization){
            case(null) { state; };
            case(?utilization) {
                // Update rates based on the new utilization
                let borrow_rate = interest_rate_curve.get_apr(utilization.ratio);
                let supply_rate = borrow_rate * utilization.ratio * (1.0 - parameters.lending_fee_ratio);
                { state with utilization; borrow_rate; supply_rate; };
            };
        };

        // Ensure timestamp is monotonic.
        // On the IC, certified block time (`time`) is not guaranteed to
        // strictly increase between messages — it can stay the same or
        // even appear to go backwards relative to our last state.
        // To explicitly account for the IC's time model and prevent
        // negative elapsed periods (which would imply "negative interest
        // accrual"), we clamp forward with Nat.max.

        // Log warning if provided time is older than state timestamp (abnormal behavior)
        if (time < state.timestamp) {
            let time_diff_ns : Int = state.timestamp - time;
            let time_diff_seconds = Float.fromInt(time_diff_ns) / Float.fromInt(Duration.NS_IN_SECOND);
            Debug.print("WARNING: Indexer received time older than state timestamp!");
            Debug.print("  Time difference: " # debug_show(time_diff_seconds) # " seconds");
        };

        let timestamp = Nat.max(time, state.timestamp);
        let elapsed_ns = Int.abs(timestamp - state.timestamp);

        // If no time has passed, no need to accrue interests nor update indexes
        if (elapsed_ns == 0) {
            return new_state;
        };

        // Calculate the time period in years
        let elapsed_annual = Duration.toAnnual(#NS(elapsed_ns));

        let supply_base = state.utilization.raw_supplied + state.accrued_interests.supply;
        let borrow_base = state.utilization.raw_borrowed + state.accrued_interests.borrow;

        // Accrue the supply interests up to this date using the previous state up to this date!
        let supply_interests = supply_base * state.supply_rate * elapsed_annual;
        let borrow_interests = borrow_base * state.borrow_rate * elapsed_annual;

        let accrued_interests = {
            supply = state.accrued_interests.supply + supply_interests;
            borrow = state.accrued_interests.borrow + borrow_interests;
        };

        var borrow_index = state.borrow_index;
        var supply_index = state.supply_index;
        // Update the indexes based on the new rates
        // Do not update indexes if utilization is null: because borrow rate can be > 0
        // even if utilization is null, this check avoids compounding the indexes for nothing
        if (state.utilization.ratio > 0) {
            borrow_index := {
                value = state.borrow_index.value * (1.0 + state.borrow_rate * elapsed_annual);
                timestamp;
            };
            supply_index := {
                value = state.supply_index.value * (1.0 + state.supply_rate * elapsed_annual);
                timestamp;
            };
        };

        return { new_state with accrued_interests; borrow_index; supply_index; timestamp; };
    };

};