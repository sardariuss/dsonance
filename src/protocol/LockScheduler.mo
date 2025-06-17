import Types "Types";
import Timeline "utils/Timeline";

import BTree "mo:stableheapbtreemap/BTree";
import Map "mo:map/Map";
import Order "mo:base/Order";
import Text "mo:base/Text";
import Int "mo:base/Int";
import Debug "mo:base/Debug";
import Option "mo:base/Option";
import Nat "mo:base/Nat";

module {

    type Lock = Types.Lock;
    type Map<K, V> = Map.Map<K, V>;
    type BTree<K, V> = BTree.BTree<K, V>;
    type Order = Order.Order;
    type Iter<T> = Map.Iter<T>;
    type Timeline<T> = Types.Timeline<T>;
    type LockEvent = Types.LockEvent;
    type LockSchedulerState = Types.LockSchedulerState;
    type LockState = Types.LockState;
    type BeforeChangeArgs = Types.BeforeChangeArgs;
    type AfterChangeArgs = Types.AfterChangeArgs;

    public func compare_locks(a: Lock, b: Lock) : Order {
        switch(Int.compare(a.release_date, b.release_date)){
            case(#less) { #less; };
            case(#greater) { #greater; };
            case(#equal) { Text.compare(a.id, b.id); };
        };
    };

    public class LockScheduler({
        state: LockSchedulerState;
        before_change: BeforeChangeArgs -> ();
        after_change: AfterChangeArgs -> ();
    }) {

        public func add(new: Lock, previous: Iter<Lock>, time: Nat) {

            try_unlock(time);

            before_change({ time; state = get_state(); });

            // Add the new lock
            if (has_lock(new.id)) {
                Debug.trap("The lock already exists");
            };
            add_lock(new);

            // Update the previous locks because their release date might have changed
            for (prev in previous){
                // Update the lock only if it exists
                Option.iterate(remove_lock(prev.id), func(old: Lock) {
                    // Assert that they have the same amount
                    if (prev.amount != old.amount) {
                        Debug.trap("The locks don't have the same amount");
                    };
                    add_lock(prev);
                });
            };

            // Update the total locked value
            let new_tvl = Timeline.current(state.tvl) + new.amount;
            Timeline.insert(state.tvl, time, new_tvl);

            after_change({ time; event = #LOCK_ADDED(new); state = get_state();});
        };

        public func try_unlock(time: Nat) {

            while (true) {
                switch(BTree.min(state.btree)) {
                    case(null) { return; };
                    case(?(lock, _)) {
                        
                        // Stop here if release date is greater than now
                        if (lock.release_date > time) { return; };

                        before_change({ time = lock.release_date; state = get_state(); });

                        ignore remove_lock(lock.id);
                        
                        let new_tvl = do {
                            let diff : Int = Timeline.current(state.tvl) - lock.amount;
                            if (diff < 0) {
                                Debug.trap("Total locked value cannot be negative");
                            };
                            Int.abs(diff);
                        };
                        
                        // Update the total locked value
                        Timeline.insert(state.tvl, lock.release_date, new_tvl);
                        
                        after_change({ time = lock.release_date; event = #LOCK_REMOVED(lock); state = get_state(); });
                    };
                };
            };
        };

        func remove_lock(lock_id: Text) : ?Lock {

            switch(Map.remove(state.map, Map.thash, lock_id)) {
                case(null) { null; };
                case(?old) {
                    ignore BTree.delete(state.btree, compare_locks, old);
                    ?old;
                };
            };
        };

        func add_lock(lock: Lock) {

            Map.set(state.map, Map.thash, lock.id, lock);
            ignore BTree.insert(state.btree, compare_locks, lock, ());
        };

        func has_lock(lock_id: Text) : Bool {

            switch(Map.get(state.map, Map.thash, lock_id)){
                case(null) { false; };
                case(?lock) { 
                    BTree.has(state.btree, compare_locks, lock);
                };
            };
        };

        public func get_state() : LockState {
            {
                locks = Map.vals(state.map);
                tvl = Timeline.current(state.tvl);
            };
        };

    };

};