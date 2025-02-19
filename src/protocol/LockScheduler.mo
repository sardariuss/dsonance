import Types "Types";
import Timeline "utils/Timeline";
import Incentives "votes/Incentives";
import Duration "duration/Duration";
import DebtProcessor "DebtProcessor";

import BTree "mo:stableheapbtreemap/BTree";
import Order "mo:base/Order";
import Text "mo:base/Text";
import Int "mo:base/Int";
import Debug "mo:base/Debug";
import Float "mo:base/Float";

module {

    type UUID = Types.UUID;
    type Lock = Types.Lock;
    type BTree<K, V> = BTree.BTree<K, V>;
    type Order = Order.Order;
    type YesNoBallot = Types.Ballot<Types.YesNoChoice>;
    type LockRegister = Types.LockRegister;
    type Timeline<T> = Types.Timeline<T>;
    type ProtocolParameters = Types.ProtocolParameters;
    type Foresight = Types.Foresight;

    public func compare_locks(a: Lock, b: Lock) : Order {
        switch(Int.compare(a.release_date, b.release_date)){
            case(#less) { #less; };
            case(#greater) { #greater; };
            case(#equal) { Text.compare(a.id, b.id); };
        };
    };

    public class LockScheduler({
        parameters: ProtocolParameters;
        lock_register: LockRegister;
        update_lock_duration: (YesNoBallot, Nat) -> ();
        dsn_debt: DebtProcessor.DebtProcessor;
        btc_debt: DebtProcessor.DebtProcessor;
    }) {

        let yield = {
            var cumulated = 0.0;
            rate = 0.1; // TODO: should change depending on usage
        };

        type YieldContributions = {
            var sum_cumulated: Float;
            var sum_current: Float;
        };

        // TODO: should not be public but it is required for ballot preview
        public func refresh_lock_duration(ballot: YesNoBallot, time: Nat) {
            update_lock_duration(ballot, time);
        };

        // add
        public func add(ballot: YesNoBallot, time: Nat) {
            
            update_lock_duration(ballot, time);
            
            let lock = get_lock(ballot);
            let { locks; total_amount; } = lock_register;

            if (not BTree.has(locks, compare_locks, lock)){
                try_unlock(time);
                ignore BTree.insert(locks, compare_locks, lock, ballot);
                Timeline.add(total_amount, time, Timeline.current(total_amount) + ballot.amount);
            };
        };

        // update
        public func update(ballot: YesNoBallot, time: Nat) {
            
            try_unlock(time);

            let { locks; } = lock_register;

            // Only update the lock if it is already there
            switch(BTree.delete(locks, compare_locks, get_lock(ballot))) {
                case(null) {};
                case(_) {
                    update_lock_duration(ballot, time);
                    ignore BTree.insert(locks, compare_locks, get_lock(ballot), ballot);
                };
            };
        };

        public func try_unlock(time: Nat) {

            if (time < lock_register.time_last_dispense) {
                Debug.trap("Time shall be greater than the last dispense time");
            };

            if (time == lock_register.time_last_dispense) {
                Debug.print("Ignore try_unlock as time is the same as the last dispense time");
                return;
            };

            let { locks; total_amount; } = lock_register;

            label unlock while (true) {
                switch(BTree.min(locks)) {
                    case(null) { return; };
                    case(?(lock, ballot)) {
                        if (lock.release_date > time) { break unlock; };

                        dispense_and_update_foresights({
                            total_locked = Timeline.current(total_amount);
                            time = lock.release_date;
                        });

                        let reward = Timeline.current(ballot.foresight).reward;

                        // Trigger the transfer of the original amount and reward and delete that lock
                        // TODO: check of floating point makes sense here
                        btc_debt.add_debt({ id = ballot.ballot_id; amount = Float.fromInt(ballot.amount + reward); time = lock.release_date; });
                        ignore BTree.delete(locks, compare_locks, lock);

                        // Update the total locked, cumulated yield and last dispense time
                        // TODO: update yield_contribution
                        Timeline.add(total_amount, lock.release_date, Timeline.current(total_amount) - ballot.amount);
                        yield.cumulated -= Float.fromInt(reward);
                    };
                };
            };

            // Dispense the remaining contribution until now
            dispense_and_update_foresights({
                total_locked = Timeline.current(total_amount);
                time;
            });
        };

        public func get_total_locked() : Timeline<Nat> {
            lock_register.total_amount;
        };

        func dispense_and_update_foresights({total_locked: Nat; time: Nat;}) {

            let period = time - lock_register.time_last_dispense;

            if (period < 0) {
                Debug.trap("Cannot dispense contribution in the past");
            };

            // Skip if the period is null
            if (period == 0) {
                return;
            };

            Debug.print("Dispensing contribution over period: " # debug_show(period));

            let { contribution_per_ns } = parameters;

            let yield_contributions = {
                var sum_current = 0.0;
                var sum_cumulated = 0.0;
            };

            // Dispense contribution over the period
            for ((lock, ballot) in BTree.entries(lock_register.locks)) {

                // Compute yield contribution
                let discernment = compute_discernment(ballot);
                yield_contributions.sum_current += Float.fromInt(ballot.amount) * discernment;
                yield_contributions.sum_cumulated += Float.fromInt(ballot.amount) * Float.fromInt(time - ballot.timestamp) * discernment;

                // DSN Contribution
                let earned = Timeline.current(ballot.contribution).earned;
                let to_add = (Float.fromInt(ballot.amount) / Float.fromInt(total_locked)) * Float.fromInt(period) * contribution_per_ns;
                let pending = (Float.fromInt(ballot.amount) / Float.fromInt(total_locked)) * Float.fromInt(lock.release_date - time) * contribution_per_ns;

                // Save in the contribution timeline
                Timeline.add(ballot.contribution, time, { earned = earned + to_add; pending; });
                
                // Transfer the contribution right away
                dsn_debt.add_debt({ id = lock.id; amount = to_add; time; });
            };

            Debug.print("time: " # debug_show(time));
            Debug.print("lock_register.time_last_dispense: " # debug_show(lock_register.time_last_dispense));
            Debug.print("period: " # debug_show(period));
            Debug.print("total_locked: " # debug_show(total_locked));
            Debug.print("yield_contributions.sum_current: " # debug_show(yield_contributions.sum_current));
            Debug.print("yield_contributions.sum_cumulated: " # debug_show(yield_contributions.sum_cumulated));

            // Update ballots foresight
            for ((lock, ballot) in BTree.entries(lock_register.locks)){
                Timeline.add(ballot.foresight, time, compute_ballot_foresight(lock, ballot, yield_contributions, time));
            };

            // Update the last dispense time
            lock_register.time_last_dispense := time;
        };

        public func get_last_dispense() : Nat {
            lock_register.time_last_dispense;
        };

        func compute_ballot_foresight(lock: Lock, ballot: YesNoBallot, yield_contributions: YieldContributions, time: Nat) : Foresight {

            let discernment = compute_discernment(ballot);
            let ballot_cumulated_yield_contribution = Float.fromInt(ballot.amount) * Float.fromInt(time - ballot.timestamp) * discernment;
            let ballot_current_yield_contribution = Float.fromInt(ballot.amount) * discernment;
            let remaining_duration = Float.fromInt(lock.release_date - time) / Float.fromInt(Duration.NS_IN_YEAR);
            // Actual reward accumulated until now
            let actual_reward = (ballot_cumulated_yield_contribution / yield_contributions.sum_cumulated) * yield.cumulated;
            // Projected reward until the end of the lock
            let projected_reward = (ballot_current_yield_contribution / yield_contributions.sum_current) 
                * yield.rate * remaining_duration * Float.fromInt(Timeline.current(lock_register.total_amount));
            let reward = Int.abs(Float.toInt(actual_reward + projected_reward));
            let apr = (100 * Float.fromInt(reward) / Float.fromInt(ballot.amount)) / remaining_duration;
            {
                reward;
                apr = {
                    current = apr;
                    potential = apr / Timeline.current(ballot.consent);
                };
            };
        };

        func compute_discernment(ballot: YesNoBallot) : Float {
            Incentives.compute_discernment({
                dissent = ballot.dissent;
                consent = Timeline.current(ballot.consent);
                lock_duration = get_lock(ballot).release_date - ballot.timestamp;
                parameters;
            });
        };

        func get_lock(ballot: YesNoBallot) : Lock {
            switch(ballot.lock){
                case(null) { Debug.trap("The ballot does not have a lock"); };
                case(?lock) {
                    { 
                        release_date = lock.release_date;
                        id = ballot.ballot_id; 
                    };
                };
            };
        };

    };

};