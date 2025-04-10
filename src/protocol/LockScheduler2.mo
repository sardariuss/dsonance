import Types "Types";

import BTree "mo:stableheapbtreemap/BTree";
import Order "mo:base/Order";
import Text "mo:base/Text";
import Int "mo:base/Int";
import Debug "mo:base/Debug";

import Map "mo:map/Map";

module {

    type Lock = Types.Lock;
    type Map<K, V> = Map.Map<K, V>;
    type BTree<K, V> = BTree.BTree<K, V>;
    type Order = Order.Order;

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

        public func add(lock: Lock) {

            // Check if there is already a lock with that ID
            if (Map.has(map, Map.thash, lock.id)) {
                Debug.trap("The lock already exists");
            };

            Map.set(map, Map.thash, lock.id, lock);
            ignore BTree.insert(btree, compare_locks, lock, ());
            
            // @todo: call refresh_unlock_timer
        };

        public func update(lock: Lock) {

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

            // @todo: call refresh_unlock_timer
        };

        public func try_unlock(time: Nat) {

            label unlock while (true) {
                switch(BTree.min(btree)) {
                    case(null) { return; };
                    case(?(lock, _)) {
                        
                        if (lock.release_date > time) { 
                            // @todo: call refresh_unlock_timer
                            break unlock; 
                        };

                        // Remove the lock
                        ignore BTree.delete(btree, compare_locks, lock);
                    };
                };
            };
        };

    };

};