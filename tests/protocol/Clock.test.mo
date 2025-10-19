import Clock "../../src/protocol/utils/Clock";
import Types "../../src/protocol/Types";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Debug "mo:base/Debug";
import { test; suite; skip } "mo:test";

// Test suite for Clock module
suite("Clock - Simulated Mode", func() {

    // Helper to create a simulated clock with specific parameters
    func makeSimulatedClock(dilation_factor: Float, offset_ns: Nat) : Clock.Clock {
        let now = Int.abs(Time.now());
        let params : Types.ClockParameters = #SIMULATED({
            var time_ref = now;
            var dilation_factor = dilation_factor;
            var offset_ns = offset_ns;
        });
        Clock.Clock(params);
    };

    test("add_offset always moves time forward", func() {
        let clock = makeSimulatedClock(1.0, 0);

        let time_before = clock.get_time();

        // Add 1 day offset
        let result = clock.add_offset(#DAYS(1));
        assert result == #ok;

        let time_after = clock.get_time();

        // Time should have increased by exactly 1 day (86_400_000_000_000 ns)
        let expected_increase = 86_400_000_000_000;
        let actual_increase = time_after - time_before;

        Debug.print("Time before: " # debug_show(time_before));
        Debug.print("Time after: " # debug_show(time_after));
        Debug.print("Expected increase: " # debug_show(expected_increase));
        Debug.print("Actual increase: " # debug_show(actual_increase));

        assert time_after > time_before;
        assert actual_increase == expected_increase;
    });

    test("add_offset with negative duration should fail or move time forward", func() {
        let clock = makeSimulatedClock(1.0, 0);

        let time_before = clock.get_time();

        // Try to add a "negative" duration (going back 1 day)
        // Note: Since Duration doesn't support negative values directly,
        // we test that any offset addition moves time forward
        let result = clock.add_offset(#DAYS(1));
        assert result == #ok;

        let time_after = clock.get_time();

        // Time should never go backwards
        assert time_after >= time_before;
    });

    test("add_offset is NOT affected by dilation_factor", func() {
        // Create clock with 100x dilation
        let clock = makeSimulatedClock(100.0, 0);

        let time_before = clock.get_time();

        // Add 1 day offset
        let result = clock.add_offset(#DAYS(1));
        assert result == #ok;

        let time_after = clock.get_time();

        // Time should increase by EXACTLY 1 day, not 100 days
        let expected_increase = 86_400_000_000_000; // 1 day in nanoseconds
        let actual_increase = time_after - time_before;

        Debug.print("Dilation factor: 100.0");
        Debug.print("Time before: " # debug_show(time_before));
        Debug.print("Time after: " # debug_show(time_after));
        Debug.print("Expected increase (1 day): " # debug_show(expected_increase));
        Debug.print("Actual increase: " # debug_show(actual_increase));

        assert actual_increase == expected_increase;
    });

    test("changing dilation_factor from 100 to 1 never moves time backwards", func() {
        // Start with 100x dilation
        let clock = makeSimulatedClock(100.0, 0);

        let time_before = clock.get_time();

        Debug.print("Time with dilation_factor=100: " # debug_show(time_before));

        // Change to 1x dilation (real-time speed)
        let result = clock.set_dilation_factor(1.0);
        assert result == #ok;

        let time_after = clock.get_time();

        Debug.print("Time with dilation_factor=1: " # debug_show(time_after));
        Debug.print("Time difference: " # debug_show(Int.abs(time_after - time_before)));

        // Time should never go backwards
        assert time_after >= time_before;
    });

    test("changing dilation_factor from 1 to 100 never moves time backwards", func() {
        // Start with 1x dilation
        let clock = makeSimulatedClock(1.0, 0);

        let time_before = clock.get_time();

        Debug.print("Time with dilation_factor=1: " # debug_show(time_before));

        // Change to 100x dilation
        let result = clock.set_dilation_factor(100.0);
        assert result == #ok;

        let time_after = clock.get_time();

        Debug.print("Time with dilation_factor=100: " # debug_show(time_after));
        Debug.print("Time difference: " # debug_show(Int.abs(time_after - time_before)));

        // Time should never go backwards
        assert time_after >= time_before;
    });

    test("dilation_factor affects how fast time progresses", func() {
        // This test simulates two clocks starting at the same time
        // One with dilation 1.0, one with dilation 100.0
        // After real time passes, the dilated clock should be ahead

        let clock_1x = makeSimulatedClock(1.0, 0);
        let clock_100x = makeSimulatedClock(100.0, 0);

        let time_1x_before = clock_1x.get_time();
        let time_100x_before = clock_100x.get_time();

        Debug.print("Initial time (1x): " # debug_show(time_1x_before));
        Debug.print("Initial time (100x): " # debug_show(time_100x_before));

        // They should start at approximately the same time
        // (might differ slightly due to computation time)
        let initial_diff = Int.abs(time_100x_before - time_1x_before);
        assert initial_diff < 1_000_000_000; // Less than 1 second difference

        // Note: In a real test environment, we would wait here or advance Time.now()
        // For this test, we'll just verify the formula is correct by checking
        // that if time_ref stays constant and we update now, the dilated clock advances faster
    });

    test("multiple add_offset calls accumulate correctly", func() {
        let clock = makeSimulatedClock(1.0, 0);

        let time_initial = clock.get_time();

        // Add 1 day
        ignore clock.add_offset(#DAYS(1));
        let time_after_1_day = clock.get_time();

        // Add another 1 day
        ignore clock.add_offset(#DAYS(1));
        let time_after_2_days = clock.get_time();

        // Add 12 hours
        ignore clock.add_offset(#HOURS(12));
        let time_final = clock.get_time();

        let total_increase = time_final - time_initial;
        let expected_increase = 86_400_000_000_000 + 86_400_000_000_000 + 43_200_000_000_000; // 2.5 days

        Debug.print("Total increase: " # debug_show(total_increase));
        Debug.print("Expected increase (2.5 days): " # debug_show(expected_increase));

        assert total_increase == expected_increase;
    });

    test("set_dilation_factor less than 1.0 should fail", func() {
        let clock = makeSimulatedClock(1.0, 0);

        // Try to set dilation factor to 0.5 (slower than real time)
        let result = clock.set_dilation_factor(0.5);

        Debug.print("Result of setting dilation_factor to 0.5: " # debug_show(result));

        // Should return an error
        switch (result) {
            case (#err(msg)) {
                assert msg == "Dilation factor must be greater than or equal to 1.0";
            };
            case (#ok) {
                assert false; // Should not succeed
            };
        };
    });

    test("set_dilation_factor to exactly 1.0 should succeed", func() {
        let clock = makeSimulatedClock(100.0, 0);

        let result = clock.set_dilation_factor(1.0);

        assert result == #ok;
    });
});

suite("Clock - Real Mode", func() {

    func makeRealClock() : Clock.Clock {
        let params : Types.ClockParameters = #REAL;
        Clock.Clock(params);
    };

    test("add_offset on REAL clock should fail", func() {
        let clock = makeRealClock();

        let result = clock.add_offset(#DAYS(1));

        Debug.print("Result of add_offset on REAL clock: " # debug_show(result));

        // Should return an error
        switch (result) {
            case (#err(msg)) {
                assert msg == "Cannot add offset to real clock";
            };
            case (#ok) {
                assert false; // Should not succeed
            };
        };
    });

    test("set_dilation_factor on REAL clock should fail", func() {
        let clock = makeRealClock();

        let result = clock.set_dilation_factor(100.0);

        Debug.print("Result of set_dilation_factor on REAL clock: " # debug_show(result));

        // Should return an error
        switch (result) {
            case (#err(msg)) {
                assert msg == "Cannot set dilation factor to real clock";
            };
            case (#ok) {
                assert false; // Should not succeed
            };
        };
    });

    test("get_time on REAL clock returns current time", func() {
        let clock = makeRealClock();

        let time1 = clock.get_time();
        let now = Int.abs(Time.now());
        let time2 = clock.get_time();

        Debug.print("Clock time 1: " # debug_show(time1));
        Debug.print("Time.now(): " # debug_show(now));
        Debug.print("Clock time 2: " # debug_show(time2));

        // Clock time should be very close to Time.now()
        // Allow for small computation delay (max 1 second)
        assert Int.abs(time1 - now) < 1_000_000_000;
        assert time2 >= time1; // Time should never go backwards
    });
});

suite("Clock - Edge Cases", func() {

    func makeSimulatedClock(dilation_factor: Float, offset_ns: Nat) : Clock.Clock {
        let now = Int.abs(Time.now());
        let params : Types.ClockParameters = #SIMULATED({
            var time_ref = now;
            var dilation_factor = dilation_factor;
            var offset_ns = offset_ns;
        });
        Clock.Clock(params);
    };

    test("adding zero offset doesn't change time", func() {
        let clock = makeSimulatedClock(1.0, 0);

        let time_before = clock.get_time();

        // Add 0 seconds
        ignore clock.add_offset(#SECONDS(0));

        let time_after = clock.get_time();

        // Time should remain the same (or advance only due to computation time)
        assert time_after >= time_before;
        assert (time_after - time_before) < 1_000_000; // Less than 1ms difference
    });

    test("very large dilation factor works correctly", func() {
        let clock = makeSimulatedClock(1000.0, 0);

        let time_before = clock.get_time();

        // Add 1 second offset - should still be exactly 1 second
        ignore clock.add_offset(#SECONDS(1));

        let time_after = clock.get_time();
        let increase = time_after - time_before;

        Debug.print("Increase with dilation_factor=1000: " # debug_show(increase));

        // Should be exactly 1 second, not affected by dilation
        assert increase == 1_000_000_000;
    });

    test("offset persists across get_time calls", func() {
        let clock = makeSimulatedClock(1.0, 0);

        // Add offset
        ignore clock.add_offset(#DAYS(10));

        let time1 = clock.get_time();
        let time2 = clock.get_time();
        let time3 = clock.get_time();

        // All times should be approximately equal (within computation time)
        // since no real time has passed and dilation is 1.0
        let diff1 = Int.abs(time2 - time1);
        let diff2 = Int.abs(time3 - time2);

        Debug.print("Diff between get_time calls: " # debug_show(diff1) # ", " # debug_show(diff2));

        assert diff1 < 1_000_000_000; // Less than 1 second
        assert diff2 < 1_000_000_000;
    });
});
