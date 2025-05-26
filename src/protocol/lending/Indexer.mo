import Int "mo:base/Int";
import Float "mo:base/Float";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";
import Result "mo:base/Result";

import InterestRateCurve "InterestRateCurve";
import Math "../utils/Math";
import Types "../Types";
import Duration "../duration/Duration";
import LendingTypes "Types";
import Clock "../utils/Clock";
import UtilizationUpdater "UtilizationUpdater";

module {

    type Duration = Types.Duration;
    type Result<Ok, Err> = Result.Result<Ok, Err>;

    type Index                 = LendingTypes.Index;
    type LendingPoolParameters = LendingTypes.LendingPoolParameters;
    type IndexerState          = LendingTypes.IndexerState;
    type SIndexerState         = LendingTypes.SIndexerState;
    type Utilization           = LendingTypes.Utilization;

    public class Indexer({
        parameters: LendingPoolParameters;
        state: IndexerState;
        interest_rate_curve: InterestRateCurve.InterestRateCurve;
        clock: Clock.IClock;
        utilization_updater: UtilizationUpdater.UtilizationUpdater
    }){

        public func get_state() : SIndexerState {
            update_state({ utilization = state.utilization });
            {
                utilization = state.utilization;
                supply_index = { value = state.supply_index; timestamp = state.last_update_timestamp };
                borrow_index = { value = state.borrow_index; timestamp = state.last_update_timestamp };
                last_update_timestamp = state.last_update_timestamp;
                supply_rate = state.supply_rate;
                supply_accrued_interests = state.supply_accrued_interests;
            };
        };

        public func add_raw_supplied({ amount: Nat; }) {
            let utilization = switch(utilization_updater.add_raw_supplied(state.utilization, amount)){
                case(#err(err)) { Debug.trap(err); };
                case(#ok(u)){ u; };
            };
            update_state({ utilization; });
        };

        public func remove_raw_supplied({ amount: Float; }) {
            let utilization = switch(utilization_updater.remove_raw_supplied(state.utilization, amount)){
                case(#err(err)) { Debug.trap(err); };
                case(#ok(u)){ u; };
            };
            update_state({ utilization; });
        };

        public func add_raw_borrow({ amount: Nat; }) {
            let utilization = switch(utilization_updater.add_raw_borrow(state.utilization, amount)){
                case(#err(err)) { Debug.trap(err); };
                case(#ok(u)){ u; };
            };
            update_state({ utilization; });
        };

        public func remove_raw_borrow({ amount: Float; }) {
            let utilization = switch(utilization_updater.remove_raw_borrow(state.utilization, amount)){
                case(#err(err)) { Debug.trap(err); };
                case(#ok(u)){ u; };
            };
            update_state({ utilization; });
        };

        public func split_supply_interests({ share: Float; minimum: Int; }) : Result<Int, Text> {
            update_state({ utilization = state.utilization });
            // Make sure the share is normalized
            if (not Math.is_normalized(share)) {
                return #err("Invalid interest share");
            };
            // Make sure the interests is above the minimum
            let interests_amount = Float.toInt(Float.max(Float.fromInt(minimum), get_supply_interests() * share));
            // Remove the interests from the total
            state.supply_accrued_interests -= Float.fromInt(interests_amount);
            // Return the amount
            #ok(interests_amount);
        };

        public func get_supply_interests() : Float {
            update_state({ utilization = state.utilization });
            state.supply_accrued_interests;
            // @todo: uncomment when using unsolved debts
            //state.supply_accrued_interests - Array.foldLeft<DebtEntry, Float>(asset_accounting.unsolved_debts, 0.0, func (acc: Float, debt: DebtEntry) {
                //acc + debt.amount;
            //});
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
        public func update_state({ utilization: Utilization }) {

            let time = clock.get_time();
            let elapsed_ns : Int = time - state.last_update_timestamp;

            // If the time is before the last update
            if (elapsed_ns < 0) {
                Debug.trap("Cannot update rates: time is before last update");
            } else if (elapsed_ns == 0) {
                // Sill Update the utilization
                state.utilization := utilization;
                Debug.print("Rates are already up to date");
                return;
            };

            // Calculate the time period in years
            let elapsed_annual = Duration.toAnnual(Duration.getDuration({ from = state.last_update_timestamp; to = time; }));

            // Accrue the supply interests up to this date, need to be done before updating anything else!
            state.supply_accrued_interests += utilization.raw_supplied * state.supply_rate * elapsed_annual;

            // Update the utilization
            state.utilization := utilization;

            // Get the current rates from the curve
            let borrow_rate = Math.percentage_to_ratio(interest_rate_curve.get_apr(state.utilization.ratio));
            state.supply_rate := borrow_rate * state.utilization.ratio * (1.0 - parameters.protocol_fee);

            // Update the indexes
            state.borrow_index := state.borrow_index * (1.0 + borrow_rate * elapsed_annual);
            state.supply_index := state.supply_index * (1.0 + state.supply_rate * elapsed_annual);
            
            // Refresh update timestamp
            state.last_update_timestamp := time;
        };

    };

};