import Types "../Types";
import HotMap "HotMap";
import RollingTimeline "../utils/RollingTimeline";

import DurationScaler "../duration/DurationScaler";

import Map "mo:map/Map";
import Debug "mo:base/Debug";

module {

    type Iter<T> = Map.Iter<T>;

    public type Elem = {
        timestamp: Nat;
        amount: Nat;
        decay: Float;
        var hotness: Float;
        var lock: ?Types.LockInfo;
    };

    public class LockInfoUpdater({
        duration_scaler: DurationScaler.IDurationScaler;
    }) {

        public func add(new: Elem, previous: Iter<Elem>, time: Nat) {

            HotMap.add_new({
                iter = previous;
                elem = new;
            });

            // Add the lock info to the new elem
            let duration_ns = duration_scaler.compute_duration_ns(new.hotness);
            let release_date = new.timestamp + duration_ns;
            new.lock := ?{
                duration_ns = RollingTimeline.make1h4y(time, duration_ns);
                var release_date = release_date;
            };

            // Update the lock info of the previous elems
            label update_previous for (prev in previous.reset()) {

                let lock = switch(prev.lock){
                    case(null) { Debug.trap("The previous lock is missing"); };
                    case(?l) { l; };
                };

                // Do not update already released elems
                if (lock.release_date < time){
                    continue update_previous;
                };
                
                // Compute the new duration and release date
                let duration_ns = duration_scaler.compute_duration_ns(prev.hotness);
                let release_date = prev.timestamp + duration_ns;

                // Update the lock info only if it has changed
                if (release_date != lock.release_date) {
                    RollingTimeline.insert(lock.duration_ns, time, duration_ns);
                    lock.release_date := release_date;
                };
            };

        };

    };
};