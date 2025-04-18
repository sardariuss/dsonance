import Types "Types";
import Timeline "utils/Timeline";

import Timer "mo:base/Timer";
import BTree "mo:stableheapbtreemap/BTree";
import Map "mo:map/Map";
import Time "mo:base/Time";
import Order "mo:base/Order";
import Text "mo:base/Text";
import Int "mo:base/Int";
import Debug "mo:base/Debug";
import Option "mo:base/Option";
import Nat "mo:base/Nat";

// TODO: use Clock instead of Time module
module {

    type Lock = Types.Lock and { amount: Nat; };
    type Map<K, V> = Map.Map<K, V>;
    type BTree<K, V> = BTree.BTree<K, V>;
    type Order = Order.Order;
    type Iter<T> = Map.Iter<T>;
    type Timeline<T> = Types.Timeline<T>;
    type LockEvent = Types.LockEvent;
    type LockSchedulerState = Types.LockSchedulerState;

    let EXPIRED_LOCK_TIMER_DURATION = #seconds(2);

    public func compare_locks(a: Lock, b: Lock) : Order {
        switch(Int.compare(a.release_date, b.release_date)){
            case(#less) { #less; };
            case(#greater) { #greater; };
            case(#equal) { Text.compare(a.id, b.id); };
        };
    };

    public class LockScheduler({
        state: LockSchedulerState;
        on_change: { event: LockEvent; new_tvl: Nat; time: Nat; } -> ();
    }) {

        var timer_id: ?Timer.TimerId = null;
        // @todo: need to start timer at the beginning or put a public function to do it

        public func get_state() : LockSchedulerState {
            state;
        };

        public func add(new: Lock, previous: Iter<Lock>, time: Nat) : async*() {

            // Add the new lock
            if (has_lock(new.id)) {
                Debug.trap("The lock already exists");
            };
            add_lock(new);

            // Update the previous locks
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

            on_change({
                event = #LOCK_ADDED(new);
                new_tvl;
                time;
            });

            // Refresh the timer
            await* refresh_timer();
        };

        func refresh_timer() : async* () {
            
            // Cancel the current timer if it exists
            switch (timer_id) {
                case (?id) { Timer.cancelTimer(id); };
                case (null) {};
            };

            // Set a new timer based on the earliest lock
            switch (BTree.min(state.btree)) {
                case (null) { timer_id := null; }; // No locks, no timer needed
                case (?(lock, _)) {
                    let now = Int.abs(Time.now());
                    
                    let difference : Int = lock.release_date - now;
                    
                    let duration = do {
                        if (difference > 0) {
                            #nanoseconds(Int.abs(difference));
                        } else {
                            EXPIRED_LOCK_TIMER_DURATION;
                        };
                    };
                    
                    timer_id := ?Timer.setTimer<system>( duration, func() : async() {
                        await* try_unlock();
                    });
                };
            };
        };

        func try_unlock() : async* (){

            let time = Int.abs(Time.now());

            while (true) {
                switch(BTree.min(state.btree)) {
                    case(null) { 
                        timer_id := null; // No more locks, clear the timer
                        return; 
                    };
                    case(?(lock, _)) {
                        
                        if (lock.release_date > time) { 
                            await* refresh_timer(); 
                            return;
                        };

                        ignore remove_lock(lock.id);
                        
                        let new_tvl = do {
                            let diff : Int = Timeline.current(state.tvl) - lock.amount;
                            if (diff < 0) {
                                Debug.trap("Total locked value cannot be negative");
                            };
                            Int.abs(diff);
                        };
                        
                        // Update the total locked value
                        Timeline.insert(state.tvl, time, new_tvl);
                        
                        on_change({
                            event = #LOCK_REMOVED(lock);
                            new_tvl;
                            time;
                        });
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

    };

};