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

module {

    type Duration        = Types.Duration;
    type Result<Ok, Err> = Result.Result<Ok, Err>;

    type Index                 = LendingTypes.Index;
    type IndexerParameters     = LendingTypes.IndexerParameters;
    type LendingIndex          = LendingTypes.LendingIndex;
    type Utilization           = LendingTypes.Utilization;
    
    type Observer = (LendingIndex) -> ();

    public class Indexer({
        index: { var value: LendingIndex; };
        parameters: IndexerParameters;
        interest_rate_curve: InterestRateCurve.InterestRateCurve;
        utilization_updater: UtilizationUpdater.UtilizationUpdater;
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
            index.value;
        };

        public func add_raw_supplied({ amount: Nat; time: Nat; }) {
            let utilization = switch(utilization_updater.add_raw_supplied(index.value.utilization, amount)){
                case(#err(err)) { Debug.trap(err); };
                case(#ok(u)){ u; };
            };
            update(?utilization, time);
        };

        public func remove_raw_supplied({ amount: Float; time: Nat; }) {
            let utilization = switch(utilization_updater.remove_raw_supplied(index.value.utilization, amount)){
                case(#err(err)) { Debug.trap(err); };
                case(#ok(u)){ u; };
            };
            update(?utilization, time);
        };

        public func add_raw_borrow({ amount: Nat; time: Nat; }) {
            let utilization = switch(utilization_updater.add_raw_borrow(index.value.utilization, amount)){
                case(#err(err)) { Debug.trap(err); };
                case(#ok(u)){ u; };
            };
            update(?utilization, time);
        };

        public func remove_raw_borrow({ amount: Float; time: Nat; }) {
            let utilization = switch(utilization_updater.remove_raw_borrow(index.value.utilization, amount)){
                case(#err(err)) { Debug.trap(err); };
                case(#ok(u)){ u; };
            };
            update(?utilization, time);
        };

        public func take_supply_interests({ amount: Nat; time: Nat; }) : Result<(), Text> {
            update(null, time);
            let accrued_interests = index.value.accrued_interests;
            let amount_float = Float.fromInt(amount);
            // Make sure the amount is not greater than available supply interests
            if (amount_float > accrued_interests.supply) {
                return #err("Amount " # debug_show(amount) # " is greater than available supply interests " # debug_show(accrued_interests.supply));
            };
            // Remove the interests from the supply
            index.value := { index.value with
                accrued_interests = { accrued_interests with
                    supply = accrued_interests.supply - amount_float;
                };
            };
            // Return the amount as Int for consistency with existing signature
            #ok;
        };

        public func update(new_utilization: ?Utilization, time: Nat) {
            
            // Update the state with the new utilization and interest rates
            index.value := update_index({
                state = index.value;
                parameters;
                interest_rate_curve;
                timestamp = time;
                new_utilization;
            });
            
            // Notify observers of the new state
            for (observer in observers.vals()) {
                observer(index.value);
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
        timestamp: Nat;
        new_utilization: ?Utilization;
    }) : LendingIndex {

        let elapsed_ns : Int = timestamp - state.timestamp;

        // If the time is before the last update
        if (elapsed_ns < 0) {
            Debug.trap("Cannot update state: time is before last update");
        };

        let new_state = switch(new_utilization){
            case(null) { state; };
            case(?utilization) {
                // Update rates based on the new utilization
                let borrow_rate = interest_rate_curve.get_apr(utilization.ratio);
                let supply_rate = borrow_rate * utilization.ratio * (1.0 - parameters.lending_fee_ratio);
                { state with utilization; borrow_rate; supply_rate; };
            };
        };

        // If no time has passed, no need to accrue interests nor update indexes
        if (elapsed_ns == 0) {
            return new_state;
        };

        // Calculate the time period in years
        let elapsed_annual = Duration.toAnnual(Duration.getDuration({ from = state.timestamp; to = timestamp; }));

        // Accrue the supply interests up to this date using the previous state up to this date!
        let supply_interests = state.utilization.raw_supplied * state.supply_rate * elapsed_annual;
        let borrow_interests = state.utilization.raw_borrowed * state.borrow_rate * elapsed_annual;

        let accrued_interests = {
            fees = 0.0; // @todo: to be removed
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