import Types    "../Types";

import Float    "mo:base/Float";
import Int      "mo:base/Int";
import Debug    "mo:base/Debug";

module {

    type Time = Int;
    type Duration = Types.Duration;
    type Decayed = Types.Decayed;

    public func add(a: Decayed, b: Decayed) : Decayed {
        switch(a) {
            case (#DECAYED(a_value)) {
                switch(b) {
                    case (#DECAYED(b_value)) {
                        #DECAYED(a_value + b_value);
                    };
                };
            };
        };
    };

    // TODO: think about factoring that model out with the one in Miner
    public class DecayModel({half_life_ns: Nat; genesis_time: Time}){

        // @todo: find out how small can the half-life be before the decay becomes too small or too big to be represented by a float64!
        let lamda = Float.log(2.0) / Float.fromInt(half_life_ns);
        let shift = Float.fromInt(genesis_time) * lamda;

        public func create_decayed(value: Float, time: Nat) : Decayed {
            #DECAYED(value * compute_decay(time)); // @todo: avoid multiplication and potential overflow ?
        };

        public func unwrap_decayed(decayed: Decayed, now: Time) : Float {
            if (now < 0) {
                Debug.trap("Unwrap decay error: invalid time, must be positive");
            };
            switch(decayed) {
                case (#DECAYED(value)) {
                    value / compute_decay(Int.abs(now));
                };
            };
        };

        public func compute_decay(time: Nat) : Float {
            Float.exp(lamda * Float.fromInt(time) - shift);
        };
        
    };
    
};