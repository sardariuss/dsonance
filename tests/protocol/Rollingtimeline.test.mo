import RollingTimeline "../../src/protocol/utils/RollingTimeline";
import Debug "mo:base/Debug";
import { test; suite } "mo:test";

suite("RollingTimeline - Basic Functionality", func() {

    let NS_IN_MINUTE : Nat = 60_000_000_000;
    let NS_IN_HOUR : Nat = 3_600_000_000_000;

    test("insert every 20 minutes - history should populate after 60 minutes", func() {
        let initialTime : Nat = 1_000_000_000_000_000_000;

        // Create a rolling timeline with 1-hour interval and max 10 entries
        let timeline = RollingTimeline.make<Nat>(initialTime, 0, NS_IN_HOUR, 10);

        Debug.print("Initial state:");
        Debug.print("  current.timestamp: " # debug_show(timeline.current.timestamp));
        Debug.print("  current.data: " # debug_show(timeline.current.data));
        Debug.print("  history size (non-null): " # debug_show(RollingTimeline.history(timeline).size()));
        Debug.print("  index: " # debug_show(timeline.index));

        // Insert entry at +20 minutes (should overwrite current, no history)
        let time1 = initialTime + (20 * NS_IN_MINUTE);
        RollingTimeline.insert(timeline, time1, 1);
        Debug.print("\nAfter insert at +20 min:");
        Debug.print("  current.data: " # debug_show(timeline.current.data));
        Debug.print("  history size: " # debug_show(RollingTimeline.history(timeline).size()));

        assert RollingTimeline.history(timeline).size() == 0;
        assert timeline.current.data == 1;

        // Insert entry at +40 minutes (should overwrite current, no history)
        let time2 = initialTime + (40 * NS_IN_MINUTE);
        RollingTimeline.insert(timeline, time2, 2);
        Debug.print("\nAfter insert at +40 min:");
        Debug.print("  current.data: " # debug_show(timeline.current.data));
        Debug.print("  history size: " # debug_show(RollingTimeline.history(timeline).size()));

        assert RollingTimeline.history(timeline).size() == 0;
        assert timeline.current.data == 2;

        // Insert entry at +60 minutes (exactly 1 hour, should add to history!)
        let time3 = initialTime + (60 * NS_IN_MINUTE);
        RollingTimeline.insert(timeline, time3, 3);
        Debug.print("\nAfter insert at +60 min (exactly 1h):");
        Debug.print("  current.data: " # debug_show(timeline.current.data));
        Debug.print("  history size: " # debug_show(RollingTimeline.history(timeline).size()));
        Debug.print("  index: " # debug_show(timeline.index));

        // With the fix, this should pass!
        assert RollingTimeline.history(timeline).size() == 1;
        assert timeline.current.data == 3;

        // Verify history entry
        let historyArray = RollingTimeline.history(timeline);
        assert historyArray.size() == 1;
        assert historyArray[0].data == 2; // The value before the checkpoint

        Debug.print("\n✅ TEST PASSED: History populated correctly after 1 hour interval!");
    });

    test("make1h4y creates correct parameters", func() {
        let initialTime : Nat = 1_000_000_000_000_000_000;
        let timeline = RollingTimeline.make1h4y<Nat>(initialTime, 42);

        assert timeline.minIntervalNs == NS_IN_HOUR;
        assert timeline.maxSize == 35_040; // 4 years of hourly data
        assert timeline.current.data == 42;
        assert timeline.index == 0;

        Debug.print("✅ TEST PASSED: make1h4y creates correct timeline!");
    });

    test("current() returns latest data", func() {
        let initialTime : Nat = 1_000_000_000_000_000_000;
        let timeline = RollingTimeline.make<Text>(initialTime, "initial", NS_IN_HOUR, 5);

        assert RollingTimeline.current(timeline) == "initial";

        RollingTimeline.insert(timeline, initialTime + NS_IN_MINUTE, "updated");
        assert RollingTimeline.current(timeline) == "updated";

        Debug.print("✅ TEST PASSED: current() returns correct data!");
    });

    test("history() returns entries in oldest-to-newest order", func() {
        let initialTime : Nat = 1_000_000_000_000_000_000;
        let timeline = RollingTimeline.make<Nat>(initialTime, 100, NS_IN_HOUR, 5);

        // Create checkpoints at 1h, 2h, 3h
        RollingTimeline.insert(timeline, initialTime + NS_IN_HOUR, 200);
        RollingTimeline.insert(timeline, initialTime + (2 * NS_IN_HOUR), 300);
        RollingTimeline.insert(timeline, initialTime + (3 * NS_IN_HOUR), 400);

        let historyArray = RollingTimeline.history(timeline);

        Debug.print("History size: " # debug_show(historyArray.size()));
        if (historyArray.size() > 0) {
            Debug.print("History entries:");
            for (i in historyArray.keys()) {
                Debug.print("  [" # debug_show(i) # "]: data=" # debug_show(historyArray[i].data));
            };
        };

        // With the fix, this should pass!
        assert historyArray.size() == 3;
        assert historyArray[0].data == 100; // Initial value
        assert historyArray[1].data == 200; // After 1h
        assert historyArray[2].data == 300; // After 2h

        Debug.print("✅ TEST PASSED: history() returns checkpoints in order!");
    });
});

suite("RollingTimeline - Ring Buffer Behavior", func() {

    let NS_IN_HOUR : Nat = 3_600_000_000_000;

    test("ring buffer wraps around when full", func() {
        let initialTime : Nat = 1_000_000_000_000_000_000;
        // Small buffer: only 3 entries
        let timeline = RollingTimeline.make<Nat>(initialTime, 0, NS_IN_HOUR, 3);

        // Fill the buffer with 3 entries
        RollingTimeline.insert(timeline, initialTime + NS_IN_HOUR, 1);
        RollingTimeline.insert(timeline, initialTime + (2 * NS_IN_HOUR), 2);
        RollingTimeline.insert(timeline, initialTime + (3 * NS_IN_HOUR), 3);

        let historyBefore = RollingTimeline.history(timeline);
        Debug.print("Buffer filled with 3 entries:");
        Debug.print("  history size: " # debug_show(historyBefore.size()));
        Debug.print("  index: " # debug_show(timeline.index));

        // Add 4th entry - should wrap around and overwrite oldest
        RollingTimeline.insert(timeline, initialTime + (4 * NS_IN_HOUR), 4);

        let historyAfter = RollingTimeline.history(timeline);
        Debug.print("\nAfter 4th entry (wrap around):");
        Debug.print("  history size: " # debug_show(historyAfter.size()));
        Debug.print("  index: " # debug_show(timeline.index));

        // Should still have 3 entries (max size)
        assert historyAfter.size() == 3;

        // Oldest entry (0) should be gone, new entries are 1, 2, 3
        assert historyAfter[0].data == 1; // Second oldest (was index 1)
        assert historyAfter[1].data == 2; // Third oldest (was index 2)
        assert historyAfter[2].data == 3; // Newest in history (was current)

        Debug.print("✅ TEST PASSED: Ring buffer wraps correctly!");
    });

    test("history() skips null entries", func() {
        let initialTime : Nat = 1_000_000_000_000_000_000;
        let timeline = RollingTimeline.make<Nat>(initialTime, 0, NS_IN_HOUR, 10);

        // Add only 2 entries to a buffer that can hold 10
        RollingTimeline.insert(timeline, initialTime + NS_IN_HOUR, 1);
        RollingTimeline.insert(timeline, initialTime + (2 * NS_IN_HOUR), 2);

        let historyArray = RollingTimeline.history(timeline);

        Debug.print("History with sparse buffer:");
        Debug.print("  maxSize: 10");
        Debug.print("  actual entries: " # debug_show(historyArray.size()));

        // Should return only non-null entries
        assert historyArray.size() == 2;
        assert historyArray[0].data == 0; // Initial value
        assert historyArray[1].data == 1; // First insert

        Debug.print("✅ TEST PASSED: Null entries skipped correctly!");
    });

    test("index wraps correctly", func() {
        let initialTime : Nat = 1_000_000_000_000_000_000;
        let timeline = RollingTimeline.make<Nat>(initialTime, 0, NS_IN_HOUR, 3);

        assert timeline.index == 0;

        // Insert 3 entries
        RollingTimeline.insert(timeline, initialTime + NS_IN_HOUR, 1);
        assert timeline.index == 1;

        RollingTimeline.insert(timeline, initialTime + (2 * NS_IN_HOUR), 2);
        assert timeline.index == 2;

        RollingTimeline.insert(timeline, initialTime + (3 * NS_IN_HOUR), 3);
        assert timeline.index == 0; // Wrapped back to 0

        RollingTimeline.insert(timeline, initialTime + (4 * NS_IN_HOUR), 4);
        assert timeline.index == 1; // Wrapped to 1

        Debug.print("✅ TEST PASSED: Index wraps correctly!");
    });
});

suite("RollingTimeline - Edge Cases", func() {

    let NS_IN_HOUR : Nat = 3_600_000_000_000;

    test("backward timestamp prints warning but doesn't trap", func() {
        let initialTime : Nat = 1_000_000_000_000_000_000;
        let timeline = RollingTimeline.make<Nat>(initialTime, 0, NS_IN_HOUR, 5);

        // Insert at +1 hour
        RollingTimeline.insert(timeline, initialTime + NS_IN_HOUR, 1);

        Debug.print("\nInserting backward timestamp (should print warning):");
        // Insert at earlier time
        RollingTimeline.insert(timeline, initialTime + (NS_IN_HOUR / 2), 2);

        // Should still update current
        assert timeline.current.data == 2;

        Debug.print("✅ TEST PASSED: Backward timestamp handled gracefully!");
    });

    test("exactly minIntervalNs should create checkpoint", func() {
        let initialTime : Nat = 1_000_000_000_000_000_000;
        let timeline = RollingTimeline.make<Nat>(initialTime, 0, NS_IN_HOUR, 5);

        // Insert at exactly 1 hour
        RollingTimeline.insert(timeline, initialTime + NS_IN_HOUR, 1);

        Debug.print("After inserting at exactly minIntervalNs:");
        Debug.print("  history size: " # debug_show(RollingTimeline.history(timeline).size()));

        // With the fix, this should pass!
        assert RollingTimeline.history(timeline).size() == 1;

        Debug.print("✅ TEST PASSED: Exact minIntervalNs creates checkpoint!");
    });

    test("just below minIntervalNs doesn't create checkpoint", func() {
        let initialTime : Nat = 1_000_000_000_000_000_000;
        let timeline = RollingTimeline.make<Nat>(initialTime, 0, NS_IN_HOUR, 5);

        // Insert at 1ns before 1 hour
        if (NS_IN_HOUR > 0) {
            RollingTimeline.insert(timeline, initialTime + NS_IN_HOUR - 1, 1);

            Debug.print("After inserting at minIntervalNs - 1:");
            Debug.print("  history size: " # debug_show(RollingTimeline.history(timeline).size()));

            // Should NOT create checkpoint
            assert RollingTimeline.history(timeline).size() == 0;
        };

        Debug.print("✅ TEST PASSED: Just below minIntervalNs doesn't checkpoint!");
    });

    test("maxSize of 1 works correctly", func() {
        let initialTime : Nat = 1_000_000_000_000_000_000;
        let timeline = RollingTimeline.make<Nat>(initialTime, 0, NS_IN_HOUR, 1);

        // Add first entry
        RollingTimeline.insert(timeline, initialTime + NS_IN_HOUR, 1);
        assert RollingTimeline.history(timeline).size() == 1;

        // Add second entry - should overwrite the first
        RollingTimeline.insert(timeline, initialTime + (2 * NS_IN_HOUR), 2);

        let historyArray = RollingTimeline.history(timeline);
        assert historyArray.size() == 1;
        assert historyArray[0].data == 1; // Only keeps one entry

        Debug.print("✅ TEST PASSED: maxSize=1 works correctly!");
    });

    test("very large maxSize doesn't cause issues", func() {
        let initialTime : Nat = 1_000_000_000_000_000_000;
        // 4 years of hourly data
        let timeline = RollingTimeline.make<Nat>(initialTime, 0, NS_IN_HOUR, 35_040);

        assert timeline.maxSize == 35_040;
        assert RollingTimeline.history(timeline).size() == 0;

        // Add a few entries
        RollingTimeline.insert(timeline, initialTime + NS_IN_HOUR, 1);
        RollingTimeline.insert(timeline, initialTime + (2 * NS_IN_HOUR), 2);

        // History should work correctly even with large buffer
        let historyArray = RollingTimeline.history(timeline);

        // With the fix, this should pass!
        assert historyArray.size() == 2;

        Debug.print("✅ TEST PASSED: Large maxSize works correctly!");
    });
});

suite("RollingTimeline - Bug Demonstration", func() {

    let NS_IN_MINUTE : Nat = 60_000_000_000;
    let NS_IN_HOUR : Nat = 3_600_000_000_000;

    test("BUG: frequent inserts prevent history accumulation", func() {
        let initialTime : Nat = 1_000_000_000_000_000_000;
        let timeline = RollingTimeline.make<Nat>(initialTime, 0, NS_IN_HOUR, 10);

        Debug.print("\n=== Demonstrating the Bug ===");
        Debug.print("Inserting every 20 minutes for 2 hours...");

        // Insert every 20 minutes for 2 hours
        RollingTimeline.insert(timeline, initialTime + (0 * 20 * NS_IN_MINUTE), 0);
        Debug.print("Insert #0 at +0min, history size: " # debug_show(RollingTimeline.history(timeline).size()));

        RollingTimeline.insert(timeline, initialTime + (1 * 20 * NS_IN_MINUTE), 1);
        Debug.print("Insert #1 at +20min, history size: " # debug_show(RollingTimeline.history(timeline).size()));

        RollingTimeline.insert(timeline, initialTime + (2 * 20 * NS_IN_MINUTE), 2);
        Debug.print("Insert #2 at +40min, history size: " # debug_show(RollingTimeline.history(timeline).size()));

        RollingTimeline.insert(timeline, initialTime + (3 * 20 * NS_IN_MINUTE), 3);
        Debug.print("Insert #3 at +60min, history size: " # debug_show(RollingTimeline.history(timeline).size()));

        RollingTimeline.insert(timeline, initialTime + (4 * 20 * NS_IN_MINUTE), 4);
        Debug.print("Insert #4 at +80min, history size: " # debug_show(RollingTimeline.history(timeline).size()));

        RollingTimeline.insert(timeline, initialTime + (5 * 20 * NS_IN_MINUTE), 5);
        Debug.print("Insert #5 at +100min, history size: " # debug_show(RollingTimeline.history(timeline).size()));

        RollingTimeline.insert(timeline, initialTime + (6 * 20 * NS_IN_MINUTE), 6);
        Debug.print("Insert #6 at +120min, history size: " # debug_show(RollingTimeline.history(timeline).size()));

        let finalHistorySize = RollingTimeline.history(timeline).size();

        Debug.print("\nFinal state:");
        Debug.print("  Total time elapsed: 120 minutes (2 hours)");
        Debug.print("  History size: " # debug_show(finalHistorySize));
        Debug.print("  Expected: At least 1 entry (after 60 min)");

        // After fix: history should accumulate correctly
        if (finalHistorySize == 0) {
            Debug.print("\n❌ BUG STILL EXISTS: No history accumulated despite 2 hours of activity!");
            Debug.print("   The window is calculated from current.timestamp instead of lastCheckpointTimestamp");
        } else {
            Debug.print("\n✅ Bug fixed! History accumulated correctly.");
            Debug.print("   Expected: At least 1 entry after 60+ minutes");
            Debug.print("   Got: " # debug_show(finalHistorySize) # " entries");
        };

        // With the fix, we should have at least 1 checkpoint (after 60 minutes)
        assert finalHistorySize >= 1;
    });
});
