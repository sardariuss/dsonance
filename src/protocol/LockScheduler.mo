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
import Buffer "mo:base/Buffer";

module {

    type UUID = Types.UUID;
    type Lock = Types.Lock;
    type BTree<K, V> = BTree.BTree<K, V>;
    type Order = Order.Order;
    type YesNoBallot = Types.Ballot<Types.YesNoChoice>;
    type LockRegister = Types.LockRegister;
    type Timeline<T> = Types.Timeline<T>;
    type ProtocolParameters = Types.ProtocolParameters;

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

        var total_yield = 0.0;
        var yield_rate = 0.1;

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

        // try_unlock
        public func try_unlock(time: Nat) {

            // Already up to date
            if (time <= lock_register.time_last_dispense) {
                return;
            };

            let { locks; total_amount; } = lock_register;

            let copy_locks = BTree.fromArray<Lock, YesNoBallot>(8, compare_locks, BTree.toArray(locks));
            var copy_total_yield = total_yield;
            var copy_total_amount = Timeline.current(total_amount);
            var copy_time_last_dispense = lock_register.time_last_dispense;

            let to_delete = Buffer.Buffer<Lock>(0);

            // Iterate over the locks in order of release date
            for ((lock, ballot) in BTree.entries(locks)){
                let { release_date } = lock;
                // Accumulate the yield from the last dispense until that lock release date
                let dispense_interval = Float.fromInt(release_date - copy_time_last_dispense) / Float.fromInt(Duration.NS_IN_YEAR);
                copy_total_yield += Float.fromInt(copy_total_amount) * dispense_interval * yield_rate;
                // Compute the reward for the lock
                let reward = Float.toInt(compute_foresight({ lock_id = lock.id; locks = copy_locks } ) * copy_total_yield);
                let lock_duration_year = Float.fromInt(release_date - ballot.timestamp) / Float.fromInt(Duration.NS_IN_YEAR);
                let apr = (100 * Float.fromInt(reward) / Float.fromInt(ballot.amount)) / lock_duration_year;
                let foresight = {
                    reward = Int.abs(reward);
                    apr = {
                        current = apr;
                        // Dividing by the consent is similar making consent = 1 in the reward calculation
                        potential = apr / Timeline.current(ballot.consent);
                    };
                };
                Timeline.add(ballot.foresight, time, foresight);

                // Update the copies
                ignore BTree.delete(copy_locks, compare_locks, lock);
                copy_total_amount -= ballot.amount;
                copy_total_yield -= Float.fromInt(reward);
                copy_time_last_dispense := lock.release_date;

                // Need to unlock if the release date has passed
                if (lock.release_date <= time) {
                    // First dispense contribution of all locks over that period
                    dispense_contribution({
                        total_locked = Timeline.current(total_amount);
                        start = lock_register.time_last_dispense;
                        end = lock.release_date;
                    });

                    // Trigger the transfer of the original amount and reward and delete that lock
                    // TODO: check of floating point makes sense here
                    btc_debt.add_debt({ id = ballot.ballot_id; amount = Float.fromInt(ballot.amount + reward); time = lock.release_date; });
                    to_delete.add(lock);

                    // Update the total locked, cumulated yield and last dispense time
                    Timeline.add(total_amount, time, copy_total_amount);
                    total_yield := copy_total_yield;
                    lock_register.time_last_dispense := copy_time_last_dispense;
                };
            };

            // Remove locks that have been unlocked
            for (lock in to_delete.vals()) {
                ignore BTree.delete(locks, compare_locks, lock);
            };

            // Dispense the remaining contribution until now
            dispense_contribution({
                total_locked = Timeline.current(total_amount);
                start = lock_register.time_last_dispense;
                end = time;
            });
            lock_register.time_last_dispense := time;
        };

        public func get_total_locked() : Timeline<Nat> {
            lock_register.total_amount;
        };

        func dispense_contribution({total_locked: Nat; start: Nat; end: Nat;}) {

            let period = end - start;

            if (period < 0) {
                Debug.trap("Cannot dispense contribution in the past");
            };

            // Skip if the period is null
            if (period == 0) {
                return;
            };

            Debug.print("Dispensing contribution over period: " # debug_show(period));

            // Dispense contribution over the period
            label dispense for ((lock, ballot) in BTree.entries(lock_register.locks)) {

                let { contribution_per_ns } = parameters;

                let earned = Timeline.current(ballot.contribution).earned;
                let to_add = (Float.fromInt(ballot.amount) / Float.fromInt(total_locked)) * Float.fromInt(period) * contribution_per_ns;
                let pending = (Float.fromInt(ballot.amount) / Float.fromInt(total_locked)) * Float.fromInt(lock.release_date - end) * contribution_per_ns;

                // Save in the contribution timeline
                Timeline.add(ballot.contribution, end, { earned = earned + to_add; pending; });
                
                // Transfer the contribution right away
                dsn_debt.add_debt({ id = lock.id; amount = to_add; time = end; });
            };
        };

        public func get_last_dispense() : Nat {
            lock_register.time_last_dispense;
        };

        func compute_foresight({lock_id: Text; locks: BTree<Lock, YesNoBallot>}) : Float {
            var total = 0.0;
            var current : ?Float = null;
            for ((l, b) in BTree.entries(locks)){
                // TODO: save the discernment in the ballot?
                let foresight = compute_discernment(b) * Float.fromInt(b.amount) * Float.fromInt(l.release_date - b.timestamp);
                total += foresight;
                if (l.id == lock_id){
                    current := ?foresight;
                };
            };
            switch(current){
                case(null) { Debug.trap("Lock not found in the locks"); };
                case(?c) { c / total; };
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