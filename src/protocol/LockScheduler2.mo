import Types "Types";
import Timer "mo:base/Timer";
import BTree "mo:stableheapbtreemap/BTree";
import Map "mo:map/Map";
import Time "mo:base/Time";

import Order "mo:base/Order";
import Text "mo:base/Text";
import Int "mo:base/Int";
import Debug "mo:base/Debug";

module {

    type Lock = Types.Lock;
    type Map<K, V> = Map.Map<K, V>;
    type BTree<K, V> = BTree.BTree<K, V>;
    type Order = Order.Order;

    let EXPIRED_LOCK_TIMER_DURATION = #seconds(2);

    public func compare_locks(a: Lock, b: Lock) : Order {
        switch(Int.compare(a.release_date, b.release_date)){
            case(#less) { #less; };
            case(#greater) { #greater; };
            case(#equal) { Text.compare(a.id, b.id); };
        };
    };

    public class LockScheduler({
        btree: BTree<Lock, ()>;
        map: Map<Text, Lock>;
    }) {
        var timer_id: ?Timer.TimerId = null;

        private func refresh_unlock_timer() : async* () {
            
            // Cancel the current timer if it exists
            switch (timer_id) {
                case (?id) { Timer.cancelTimer(id); };
                case (null) {};
            };

            // Set a new timer based on the earliest lock
            switch (BTree.min(btree)) {
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

        public func add(lock: Lock) : async*() {

            // Check if there is already a lock with that ID
            if (Map.has(map, Map.thash, lock.id)) {
                Debug.trap("The lock already exists");
            };

            Map.set(map, Map.thash, lock.id, lock);
            ignore BTree.insert(btree, compare_locks, lock, ());
            
            await* refresh_unlock_timer();
        };

        public func update(lock: Lock) : async* () {

            // Remove the old lock
            switch(Map.remove(map, Map.thash, lock.id)) {
                case(null) { Debug.trap("The lock does not exist"); };
                case(?old) {
                    // @todo: should one assert (lock.release_date <= time)?
                    ignore BTree.delete(btree, compare_locks, old);
                };
            };

            // Add the new lock
            Map.set(map, Map.thash, lock.id, lock);
            ignore BTree.insert(btree, compare_locks, lock, ());

            await* refresh_unlock_timer();
        };

        public func try_unlock() : async* (){

            let time = Int.abs(Time.now());

            while (true) {
                switch(BTree.min(btree)) {
                    case(null) { 
                        timer_id := null; // No more locks, clear the timer
                        return; 
                    };
                    case(?(lock, _)) {
                        
                        if (lock.release_date > time) { 
                            await* refresh_unlock_timer(); 
                            return;
                        };

                        // Remove the lock
                        ignore BTree.delete(btree, compare_locks, lock);
                    };
                };
            };
        };

    };

};