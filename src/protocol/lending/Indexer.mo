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
    }) {

        let observers = Buffer.Buffer<Observer>(0);

        public func add_observer(o: Observer) {
            observers.add(o);
        };

        public func get_parameters() : IndexerParameters {
            parameters
        };

        public func get_index() : LendingIndex {
            Timeline.current(index)
        };

        /// Return the precise index *at time = now*, without mutating state.
        public func get_index_now(now: Nat) : LendingIndex {
            let stored = Timeline.current(index);
            compute_index(stored, now)
        };

        // \return The updated supply index
        public func add_raw_supplied({ amount: Nat; time: Nat }) : Float {
            let current = Timeline.current(index);
            let newUtilization = UtilizationUpdater.add_raw_supplied(current.utilization, amount);
            update(?newUtilization, time).supply_index.value;
        };

        // \return The updated supply index
        public func remove_raw_supplied({ amount: Float; time: Nat }) : Float {
            let current = Timeline.current(index);
            let newUtilization = UtilizationUpdater.remove_raw_supplied(current.utilization, amount);
            update(?newUtilization, time).supply_index.value;
        };

        // \return The updated borrow index
        public func add_raw_borrow({ amount: Nat; time: Nat }) : Float {
            let current = Timeline.current(index);
            let newUtilization = switch (UtilizationUpdater.add_raw_borrow(current.utilization, amount)) {
                case (#ok(u)) u;
                case (#err(e)) Debug.trap(e);
            };
            update(?newUtilization, time).borrow_index.value;
        };

        // \return The updated borrow index
        public func remove_raw_borrow({ amount: Float; time: Nat }) : Float {
            let current = Timeline.current(index);
            let newUtilization = UtilizationUpdater.remove_raw_borrow(current.utilization, amount);
            update(?newUtilization, time).borrow_index.value;
        };

        public func simple_update(now: Nat) : LendingIndex {
            update(null, now)
        };

        func update(newUtilization: ?Utilization, now: Nat) : LendingIndex {
            let old = Timeline.current(index);

            // 1. Accrue interest up to now (using stored rates)
            var new = compute_index(old, now);

            // 2. Update rates if utilization changed
            new := switch newUtilization {
                case (null) new;
                case (?utilization) {
                    let borrow_rate = interest_rate_curve.get_apr(utilization.ratio);
                    let supply_rate = borrow_rate * utilization.ratio * (1.0 - parameters.lending_fee_ratio);
                    { new with utilization; borrow_rate; supply_rate };
                };
            };

            // 3. Insert into timeline
            Timeline.insert(index, new.timestamp, new);

            // 4. Notify observers
            for (obs in observers.vals()) {
                obs(new);
            };

            new
        };

        public func scale_supply_up({ principal: Float; past_index: Float; }) : Float {
            scale_up({ principal; past_index; new_index = get_index().supply_index.value })
        };

        public func scale_supply_down({ scaled: Float; past_index: Float; }) : Float {
            scale_down({ scaled; past_index; new_index = get_index().supply_index.value })
        };

        public func scale_borrow_up({ principal: Float; past_index: Float; }) : Float {
            scale_up({ principal; past_index; new_index = get_index().borrow_index.value })
        };

        public func scale_borrow_down({ scaled: Float; past_index: Float; }) : Float {
            scale_down({ scaled; past_index; new_index = get_index().borrow_index.value })
        };

    };

    /// Accrue interest from state.timestamp → now, using stored rates.
    public func compute_index(state: LendingIndex, now: Nat) : LendingIndex {
        // Ensure time never goes backward
        let timestamp = Nat.max(now, state.timestamp);
        let dt : Int = timestamp - state.timestamp;

        if (dt == 0 or state.utilization.ratio == 0) {
            // No elapsed time or no borrowers → no accrual
            return { state with timestamp };
        };

        let elapsedAnnual = Duration.toAnnual(#NS(Int.abs(dt)));

        let borrowIndex = {
            value = state.borrow_index.value * (1.0 + state.borrow_rate * elapsedAnnual);
            timestamp;
        };

        let supplyIndex = {
            value = state.supply_index.value * (1.0 + state.supply_rate * elapsedAnnual);
            timestamp;
        };

        {
            state
            with
            borrow_index = borrowIndex;
            supply_index = supplyIndex;
            timestamp;
        }
    };

    func scale_up({ principal: Float; past_index: Float; new_index: Float }) : Float {
        if (past_index == 0.0) { Debug.trap("past_index == 0"); };
        principal * new_index / past_index
    };

    func scale_down({ scaled: Float; past_index: Float; new_index: Float }) : Float {
        if (new_index == 0.0) { Debug.trap("new_index == 0"); };
        scaled * past_index / new_index
    };

};