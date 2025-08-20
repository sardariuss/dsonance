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
import Buffer "mo:base/Buffer";

import Set "mo:map/Set";

module {

    type Lock = Types.Lock;
    type Set<T> = Set.Set<T>;
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

            after_change({ time; event = #LOCK_ADDED(new); state = get_state();});
        };

        public func try_unlock(time: Nat) : Set<Text> {

            let removed = Set.new<Text>();

            label remove_expired while (true) {
                switch(BTree.min(state.btree)) {
                    case(null) { break remove_expired; };
                    case(?(lock, _)) {
                        
                        // Stop here if release date is greater than now
                        if (lock.release_date > time) { break remove_expired; };

                        before_change({ time = lock.release_date; state = get_state(); });

                        switch(remove_lock(lock.id)){
                            case(null) {}; // Lock not found, continue
                            case(_) {
                                ignore Set.put<Text>(removed, Set.thash, lock.id);
                            };
                        };
                        
                        after_change({ time = lock.release_date; event = #LOCK_REMOVED(lock); state = get_state(); });
                    };
                };
            };

            removed;
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
            };
        };

    };

};