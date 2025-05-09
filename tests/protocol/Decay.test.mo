import Decay "../../src/protocol/duration/Decay";
import Duration "../../src/protocol/duration/Duration";

import { test; suite; } "mo:test";
import Time "mo:base/Time";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Debug "mo:base/Debug";

import { verify; Testify; } = "../utils/Testify";

suite("Decay", func(){

    test("Simple decay", func(){
        let t0 = Time.now();
        let decay_model = Decay.DecayModel({ half_life = #HOURS(1); time_init = t0; });

        let decay_1 = decay_model.compute_decay(Int.abs(t0));
        let decay_2 = decay_model.compute_decay(Int.abs(t0) + Duration.toTime(#HOURS(1)));

        verify<Float>(decay_1,         1.0, Testify.float.equalEpsilon9);
        verify<Float>(decay_2/decay_1, 2.0, Testify.float.equalEpsilon9);

        let iter = Iter.range(1, 3);
        var test = iter.next();
        while(test != null){
            Debug.print(debug_show(test));
            test := iter.next();
        };
    });
    
})