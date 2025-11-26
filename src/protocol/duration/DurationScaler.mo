import Types            "../Types";
import RollingTimeline  "../utils/RollingTimeline";

import Float            "mo:base/Float";
import Int              "mo:base/Int";

module {

    public type IDurationScaler = {
        compute_duration_ns: Float -> Nat;
    };

    type LockInput = {
        id: Text;
        timestamp: Nat;
        amount: Nat;
        var lock: ?Types.LockInfo;
    };

    // https://www.desmos.com/calculator/n4yits420e
    // The duration scaler function is responsible for computing the lock duration of positions
    // based on the "hotness" of the pool (how much USDT is locked around the position's timestamp).
    // It uses a power scaling function to prevent absurd durations (e.g. 10 seconds or 100 years).
    // The function is defined as:
    //      duration = a * hotness ^ log(b)
    // where:
    //      a is the multiplier parameter (controls baseline duration)
    //      b is the logarithmic base parameter (controls scaling rate)
    //      hotness is the amount of USDT locked around the position's timestamp
    //
    //                                                   ································
    //  duration                         ················
    //      ↑                    ········
    //        → hotness      ····
    //                     ··
    //                    ·
    // 
    public class DurationScaler({
        a: Float;  // multiplier parameter
        b: Float;  // logarithmic base parameter
    }) : IDurationScaler {

        public func compute_duration_ns(hotness: Float) : Nat {
            Int.abs(Float.toInt(a * Float.pow(hotness, Float.log(b) / Float.log(10.0))));
        };

        // Watchout, this functions updates the lock info in place.
        public func update_lock_info(input: LockInput, hotness: Float, time: Nat) {
            let new_duration_ns = compute_duration_ns(hotness);
            let release_date = input.timestamp + new_duration_ns;
            switch(input.lock) {
                case(null) { 
                    input.lock := ?{
                        duration_ns = RollingTimeline.make1h4y(time, new_duration_ns);
                        var release_date = release_date;
                    };
                };
                case(?lock) {
                    if (release_date != lock.release_date) {
                        RollingTimeline.insert(lock.duration_ns, time, new_duration_ns);
                        lock.release_date := release_date;
                    };
                };
            };
        };
    
    };
}