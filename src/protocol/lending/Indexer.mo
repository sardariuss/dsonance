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
import Math               "../utils/Math";
import Clock              "../utils/Clock";
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
        clock: Clock.IClock;
        utilization_updater: UtilizationUpdater.UtilizationUpdater;
    }){

        let observers = Buffer.Buffer<Observer>(0);

        public func add_observer(observer: Observer) {
            observers.add(observer);
        };

        public func get_index() : LendingIndex {
            update(null);
            index.value;
        };

        public func add_raw_supplied({ amount: Nat; }) {
            let utilization = switch(utilization_updater.add_raw_supplied(index.value.utilization, amount)){
                case(#err(err)) { Debug.trap(err); };
                case(#ok(u)){ u; };
            };
            update(?utilization);
        };

        public func remove_raw_supplied({ amount: Float; }) {
            let utilization = switch(utilization_updater.remove_raw_supplied(index.value.utilization, amount)){
                case(#err(err)) { Debug.trap(err); };
                case(#ok(u)){ u; };
            };
            update(?utilization);
        };

        public func add_raw_borrow({ amount: Nat; }) {
            let utilization = switch(utilization_updater.add_raw_borrow(index.value.utilization, amount)){
                case(#err(err)) { Debug.trap(err); };
                case(#ok(u)){ u; };
            };
            update(?utilization);
        };

        public func remove_raw_borrow({ amount: Float; }) {
            let utilization = switch(utilization_updater.remove_raw_borrow(index.value.utilization, amount)){
                case(#err(err)) { Debug.trap(err); };
                case(#ok(u)){ u; };
            };
            update(?utilization);
        };

        public func take_supply_interests({ share: Float; minimum: Int; }) : Result<Int, Text> {
            update(null);
            // Make sure the share is normalized
            if (not Math.is_normalized(share)) {
                return #err("Invalid interest share");
            };
            let accrued_interests = index.value.accrued_interests;
            // Make sure the interests is above the minimum
            let interests_amount = Float.toInt(Float.max(Float.fromInt(minimum), accrued_interests.supply * share));
            // Remove the interests from the supply
            index.value := { index.value with
                accrued_interests = { accrued_interests with
                    supply = accrued_interests.supply - Float.fromInt(interests_amount);
                };
            };
            // Return the amount
            #ok(interests_amount);
        };

        public func take_supply_fees(amount: Nat) : Result<{ revert: () -> () }, Text> {
            update(null);
            // Make sure the amount is not greater than the fees
            if (Float.fromInt(amount) > index.value.accrued_interests.fees) {
                return #err("Not enough fees available to take");
            };
            // Remove the fees from the accrued interests
            index.value := { index.value with
                accrued_interests = { index.value.accrued_interests with
                    fees = index.value.accrued_interests.fees - Float.fromInt(amount);
                };
            };
            // Revert function in case the transfer fails
            let revert = func(){
                index.value := { index.value with
                    accrued_interests = { index.value.accrued_interests with
                        fees = index.value.accrued_interests.fees + Float.fromInt(amount);
                    };
                };
            };
            #ok({ revert; });
        };

        public func update(new_utilization: ?Utilization) {
            
            // Update the state with the new utilization and interest rates
            index.value := update_index({
                state = index.value;
                parameters;
                interest_rate_curve;
                timestamp = clock.get_time();
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
                let supply_rate = borrow_rate * utilization.ratio;
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
        let interests = state.utilization.raw_supplied * state.supply_rate * elapsed_annual;
        let accrued_interests = {
            fees = state.accrued_interests.fees + interests * parameters.lending_fee_ratio;
            supply = state.accrued_interests.supply + interests * (1.0 - parameters.lending_fee_ratio);
        };

        // Update the indexes based on the new rates
        // @todo: is it not (old) state rates?
        let borrow_index = {
            value = state.borrow_index.value * (1.0 + new_state.borrow_rate * elapsed_annual);
            timestamp;
        };
        let supply_index = {
            value = state.supply_index.value * (1.0 + new_state.supply_rate * elapsed_annual);
            timestamp;
        };

        return { new_state with accrued_interests; borrow_index; supply_index; timestamp; };
    };

};