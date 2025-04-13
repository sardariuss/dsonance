import Types "Types";
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

    let EXPIRED_LOCK_TIMER_DURATION = #seconds(2);

    public func compare_locks(a: Lock, b: Lock) : Order {
        switch(Int.compare(a.release_date, b.release_date)){
            case(#less) { #less; };
            case(#greater) { #greater; };
            case(#equal) { Text.compare(a.id, b.id); };
        };
    };

    type LockEvent = {
        #LOCK_ADDED: Lock;
        #LOCK_REMOVED: Lock;
    };

    type LockSchedulerArgs = {
        btree: BTree<Lock, ()>;
        map: Map<Text, Lock>;
        on_change: { event: LockEvent; new_tvl: Nat; } -> ();
        var tvl: Nat;
    };

    public class LockScheduler(args : LockSchedulerArgs) {

        var timer_id: ?Timer.TimerId = null;
        // TODO: need to start timer at the beginning or put a public function to do it

        public func get_locks() : Iter<Lock> {
            Map.vals(args.map);
        };

        public func get_tvl() : Nat {
            args.tvl;
        };

        public func add(lock: Lock) : async*() {

            if (has_lock(lock.id)) {
                Debug.trap("The lock already exists");
            };

            add_lock(lock);
            args.tvl += lock.amount;
            args.on_change({
                event = #LOCK_ADDED(lock);
                new_tvl = args.tvl;
            });
            await* refresh_timer();
        };

        public func update(locks: Iter<Lock>) : async* () {

            for (lock in locks){
                // Update the lock only if it exists
                Option.iterate(remove_lock(lock.id), func(old: Lock) {
                    // Assert that they have the same amount
                    if (lock.amount != old.amount) {
                        Debug.trap("The locks don't have the same amount");
                    };
                    add_lock(lock);
                });
            };
            
            await* refresh_timer();
        };

        private func refresh_timer() : async* () {
            
            // Cancel the current timer if it exists
            switch (timer_id) {
                case (?id) { Timer.cancelTimer(id); };
                case (null) {};
            };

            // Set a new timer based on the earliest lock
            switch (BTree.min(args.btree)) {
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

        private func try_unlock() : async* (){

            let time = Int.abs(Time.now());

            while (true) {
                switch(BTree.min(args.btree)) {
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
                        args.tvl -= lock.amount;
                        args.on_change({
                            event = #LOCK_REMOVED(lock);
                            new_tvl = args.tvl;
                        });
                    };
                };
            };
        };

        private func remove_lock(lock_id: Text) : ?Lock {

            switch(Map.remove(args.map, Map.thash, lock_id)) {
                case(null) { null; };
                case(?old) {
                    ignore BTree.delete(args.btree, compare_locks, old);
                    ?old;
                };
            };
        };

        private func add_lock(lock: Lock) {

            Map.set(args.map, Map.thash, lock.id, lock);
            ignore BTree.insert(args.btree, compare_locks, lock, ());
        };

        private func has_lock(lock_id: Text) : Bool {

            switch(Map.get(args.map, Map.thash, lock_id)){
                case(null) { false; };
                case(?lock) { 
                    BTree.has(args.btree, compare_locks, lock);
                };
            };
        };

    };

};