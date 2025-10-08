import Decay "../../src/protocol/duration/Decay";
import Duration "../../src/protocol/duration/Duration";

import { test; suite; } "mo:test";
import Time "mo:base/Time";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";

import { verify; Testify; } = "../utils/Testify";

suite("Decay", func(){

    test("Simple decay", func(){
        let t0 = Time.now();
        let half_life_ns = Duration.toTime(#HOURS(1));
        let decay_model = Decay.DecayModel({ half_life_ns; genesis_time = t0; });

        let decay_1 = decay_model.compute_decay(Int.abs(t0));
        let decay_2 = decay_model.compute_decay(Int.abs(t0) + half_life_ns);

        verify<Float>(decay_1,         1.0, Testify.float.equalEpsilon9);
        verify<Float>(decay_2/decay_1, 2.0, Testify.float.equalEpsilon9);

        let iter = Iter.range(1, 3);
        var test = iter.next();
        while(test != null){
            Debug.print(debug_show(test));
            test := iter.next();
        };
    });

    test("Decay behavior with specific timestamps", func(){
        // Test with a fixed genesis time and half-life to verify expected behavior
        let genesis_time = 1000000000000000000; // 1e18 nanoseconds (fixed reference point)
        let half_life_ns = Duration.toTime(#HOURS(1)); // 1 hour in nanoseconds
        let decay_model = Decay.DecayModel({ half_life_ns; genesis_time; });

        // At genesis time, decay should be 1.0
        let decay_at_genesis = decay_model.compute_decay(Int.abs(genesis_time));
        verify<Float>(decay_at_genesis, 1.0, Testify.float.equalEpsilon9);

        // After 1 half-life (1 hour), decay should be 2.0
        let decay_after_half_life = decay_model.compute_decay(Int.abs(genesis_time) + half_life_ns);
        verify<Float>(decay_after_half_life, 2.0, Testify.float.equalEpsilon6);

        // After 2 half-lives (2 hours), decay should be 4.0
        let decay_after_two_half_lives = decay_model.compute_decay(Int.abs(genesis_time) + 2 * half_life_ns);
        verify<Float>(decay_after_two_half_lives, 4.0, Testify.float.equalEpsilon6);

        // Before genesis time (e.g., half an hour before), decay should be 1/sqrt(2) ≈ 0.707
        let decay_before_genesis = decay_model.compute_decay(Int.abs(genesis_time) - half_life_ns / 2);
        let expected_decay_before = 1.0 / Float.sqrt(2.0);
        verify<Float>(decay_before_genesis, expected_decay_before, Testify.float.equalEpsilon6);
    });

    test("Consistency with TypeScript implementation", func(){
        // Verify that the Motoko implementation matches the TypeScript one
        let genesis_time = 1640995200000000000; // 2022-01-01 00:00:00 UTC in nanoseconds
        let half_life_ns = Duration.toTime(#MINUTES(30)); // 30 minutes
        let decay_model = Decay.DecayModel({ half_life_ns; genesis_time; });

        // Test at various time points
        let test_times = [
            genesis_time,                              // t0
            genesis_time + half_life_ns,              // t0 + 30min
            genesis_time + 2 * half_life_ns,          // t0 + 1h
            genesis_time - half_life_ns               // t0 - 30min
        ];

        let expected_decays = [1.0, 2.0, 4.0, 0.5]; // Expected decay values

        for (i in test_times.keys()) {
            let decay = decay_model.compute_decay(Int.abs(test_times[i]));
            verify<Float>(decay, expected_decays[i], Testify.float.equalEpsilon6);
        };
    });

    test("CDV calculation example from glossary", func(){
        // Test scenario from glossary.md to verify expected CDV behavior
        let genesis_time = 1000000000000000000; // Fixed reference time
        let half_life_ns = Duration.toTime(#HOURS(1)); // 1 hour half-life
        let decay_model = Decay.DecayModel({ half_life_ns; genesis_time; });

        // Alice adds a $100 ballot at t0
        let t0 = Int.abs(genesis_time);
        let alice_amount = 100.0;
        let alice_ballot = decay_model.create_decayed(alice_amount, t0);

        // At t0, CDV should be $100
        let evp_at_t0 = decay_model.unwrap_decayed(alice_ballot, genesis_time);
        verify<Float>(evp_at_t0, 100.0, Testify.float.equalEpsilon6);

        // At t1 (some time later), CDV should decrease due to decay
        // Let's say t1 is 10 minutes later
        let t1 = genesis_time + Duration.toTime(#MINUTES(10));
        let evp_at_t1 = decay_model.unwrap_decayed(alice_ballot, t1);
        
        // CDV should be less than 100 since decay increases over time
        // but the unwrap_decayed divides by a larger decay value
        // This means CDV decreases over time as expected
        Debug.print("CDV at t0: " # Float.toText(evp_at_t0));
        Debug.print("CDV at t1: " # Float.toText(evp_at_t1));
        
        // CDV should decrease over time
        let is_decreasing = evp_at_t1 < evp_at_t0;
        verify<Bool>(is_decreasing, true, Testify.bool.equal);
    });

    test("Cross-platform decay calculation verification", func(){
        // This test verifies that our Motoko implementation produces the same results
        // as the TypeScript implementation would with the same parameters

        let genesis_time = 1700000000000000000; // Jan 2024 equivalent in nanoseconds
        let half_life_ns = Duration.toTime(#MINUTES(30)); // 30 minutes
        let decay_model = Decay.DecayModel({ half_life_ns; genesis_time; });

        // Test at several specific time points
        let test_cases = [
            (genesis_time, 1.0), // At genesis, decay = 1.0
            (genesis_time + half_life_ns, 2.0), // After 1 half-life, decay = 2.0
            (genesis_time + 2 * half_life_ns, 4.0), // After 2 half-lives, decay = 4.0
            (genesis_time - half_life_ns, 0.5), // Before genesis, decay = 0.5
        ];

        Debug.print("=== Cross-platform decay verification ===");
        for (test_case in test_cases.vals()) {
            let (time, expected) = test_case;
            let decay = decay_model.compute_decay(Int.abs(time));
            Debug.print("Time: " # Int.toText(time) # ", Expected: " # Float.toText(expected) # ", Got: " # Float.toText(decay));
            verify<Float>(decay, expected, Testify.float.equalEpsilon6);
        };
    });

    test("Debug realistic CDV scenario - simplified", func(){
        // Simple test for production parameters 
        let genesis_time = 1700000000000000000;
        let production_half_life_ns = Duration.toTime(#YEARS(1));
        let decay_model = Decay.DecayModel({ half_life_ns = production_half_life_ns; genesis_time; });

        let ballot_amount = 90000.0;
        let ballot = decay_model.create_decayed(ballot_amount, Int.abs(genesis_time));
        
        let two_weeks_later = genesis_time + Duration.toTime(#DAYS(14));
        let evp_after_2_weeks = decay_model.unwrap_decayed(ballot, two_weeks_later);
        
        // After 2 weeks with 1-year half-life, CDV should be very close to original
        // If it's showing 0.1 USD instead of ~89k USD, there's a major bug
        Debug.print("CDV after 2 weeks with 1-year half-life:");
        Debug.print("Original: " # Float.toText(ballot_amount));
        Debug.print("After 2 weeks: " # Float.toText(evp_after_2_weeks));
        Debug.print("Ratio: " # Float.toText(evp_after_2_weeks / ballot_amount));
        
        let is_reasonable = evp_after_2_weeks > 80000.0; // Should be > 80k
        verify<Bool>(is_reasonable, true, Testify.bool.equal);
    });

    test("Duration conversion bug fix", func(){
        // Test the bug fix for fromTime function
        let one_year_ns = Duration.toTime(#YEARS(1));
        let converted_back = Duration.fromTime(one_year_ns);
        
        // Should convert back to YEARS(1), not DAYS(365)
        switch (converted_back) {
            case (#YEARS(years)) {
                verify<Nat>(years, 1, Testify.nat.equal);
                Debug.print("✓ Duration conversion fixed: 1 year -> " # Nat.toText(one_year_ns) # " ns -> #YEARS(1)");
            };
            case (#DAYS(days)) {
                Debug.print("✗ Duration conversion still broken: got #DAYS(" # Nat.toText(days) # ")");
                verify<Bool>(false, true, Testify.bool.equal); // Force fail
            };
            case (_) {
                Debug.print("✗ Duration conversion unexpected result");
                verify<Bool>(false, true, Testify.bool.equal); // Force fail
            };
        };
    });
    
})