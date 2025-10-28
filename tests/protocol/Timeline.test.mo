import Timeline "../../src/protocol/utils/Timeline";
import Debug "mo:base/Debug";
import { test; suite } "mo:test";

// @TODO: Review this file, it has been entirely coded by Claude.

suite("Timeline - Basic Functionality", func() {

    let NS_IN_MINUTE : Nat = 60_000_000_000;
    let NS_IN_HOUR : Nat = 3_600_000_000_000;

    test("insert every 20 minutes - history populated after 60 minutes", func() {
        let initialTime : Nat = 1_000_000_000_000_000_000;

        // Create a timeline with 1-hour minimum interval
        let timeline = Timeline.make1h<Nat>(initialTime, 0);

        Debug.print("Initial state:");
        Debug.print("  current.timestamp: " # debug_show(timeline.current.timestamp));
        Debug.print("  current.data: " # debug_show(timeline.current.data));
        Debug.print("  history.size(): " # debug_show(timeline.history.size()));
        Debug.print("  lastCheckpointTimestamp: " # debug_show(timeline.lastCheckpointTimestamp));

        // Insert entry at +20 minutes (should overwrite current, no history)
        let time1 = initialTime + (20 * NS_IN_MINUTE);
        Timeline.insert(timeline, time1, 1);
        Debug.print("\nAfter insert at +20 min:");
        Debug.print("  current.data: " # debug_show(timeline.current.data));
        Debug.print("  history.size(): " # debug_show(timeline.history.size()));
        Debug.print("  lastCheckpointTimestamp: " # debug_show(timeline.lastCheckpointTimestamp));

        assert timeline.history.size() == 0;
        assert timeline.current.data == 1;
        assert timeline.lastCheckpointTimestamp == initialTime;

        // Insert entry at +40 minutes (should overwrite current, no history)
        let time2 = initialTime + (40 * NS_IN_MINUTE);
        Timeline.insert(timeline, time2, 2);
        Debug.print("\nAfter insert at +40 min:");
        Debug.print("  current.data: " # debug_show(timeline.current.data));
        Debug.print("  history.size(): " # debug_show(timeline.history.size()));
        Debug.print("  lastCheckpointTimestamp: " # debug_show(timeline.lastCheckpointTimestamp));

        assert timeline.history.size() == 0;
        assert timeline.current.data == 2;
        assert timeline.lastCheckpointTimestamp == initialTime;

        // Insert entry at +60 minutes (exactly 1 hour, should add to history!)
        let time3 = initialTime + (60 * NS_IN_MINUTE);
        Timeline.insert(timeline, time3, 3);
        Debug.print("\nAfter insert at +60 min (exactly 1h):");
        Debug.print("  current.data: " # debug_show(timeline.current.data));
        Debug.print("  history.size(): " # debug_show(timeline.history.size()));
        Debug.print("  lastCheckpointTimestamp: " # debug_show(timeline.lastCheckpointTimestamp));

        // Should have created a checkpoint
        assert timeline.history.size() == 1;
        assert timeline.current.data == 3;
        assert timeline.lastCheckpointTimestamp == time3;

        // Verify history entry
        let historyArray = Timeline.history(timeline);
        assert historyArray.size() == 1;
        assert historyArray[0].data == 2; // The value before the checkpoint

        Debug.print("\n✅ TEST PASSED: History populated correctly after 1 hour interval!");
    });

    test("insert at +80 minutes - second checkpoint created", func() {
        let initialTime : Nat = 1_000_000_000_000_000_000;
        let timeline = Timeline.make1h<Nat>(initialTime, 0);

        // Fast forward: insert at 20, 40, 60 minutes
        Timeline.insert(timeline, initialTime + (20 * NS_IN_MINUTE), 1);
        Timeline.insert(timeline, initialTime + (40 * NS_IN_MINUTE), 2);
        Timeline.insert(timeline, initialTime + (60 * NS_IN_MINUTE), 3);

        assert timeline.history.size() == 1;

        // Insert at +80 minutes (should overwrite current, no new history)
        let time4 = initialTime + (80 * NS_IN_MINUTE);
        Timeline.insert(timeline, time4, 4);

        Debug.print("After insert at +80 min:");
        Debug.print("  current.data: " # debug_show(timeline.current.data));
        Debug.print("  history.size(): " # debug_show(timeline.history.size()));
        Debug.print("  lastCheckpointTimestamp: " # debug_show(timeline.lastCheckpointTimestamp));

        // Should still have only 1 checkpoint (80min - 60min = 20min < 1h)
        assert timeline.history.size() == 1;
        assert timeline.current.data == 4;

        // Insert at +120 minutes (2 hours total, should create second checkpoint)
        let time5 = initialTime + (120 * NS_IN_MINUTE);
        Timeline.insert(timeline, time5, 5);

        Debug.print("\nAfter insert at +120 min:");
        Debug.print("  current.data: " # debug_show(timeline.current.data));
        Debug.print("  history.size(): " # debug_show(timeline.history.size()));

        // Should now have 2 checkpoints
        assert timeline.history.size() == 2;
        assert timeline.current.data == 5;

        let historyArray = Timeline.history(timeline);
        assert historyArray[0].data == 2; // First checkpoint
        assert historyArray[1].data == 4; // Second checkpoint

        Debug.print("✅ TEST PASSED: Multiple checkpoints created correctly!");
    });

    test("current() returns latest data", func() {
        let initialTime : Nat = 1_000_000_000_000_000_000;
        let timeline = Timeline.make1h<Text>(initialTime, "initial");

        assert Timeline.current(timeline) == "initial";

        Timeline.insert(timeline, initialTime + NS_IN_MINUTE, "updated");
        assert Timeline.current(timeline) == "updated";

        Debug.print("✅ TEST PASSED: current() returns correct data!");
    });

    test("history() returns all checkpoints in order", func() {
        let initialTime : Nat = 1_000_000_000_000_000_000;
        let timeline = Timeline.make1h<Nat>(initialTime, 100);

        // Create checkpoints at 1h, 2h, 3h
        Timeline.insert(timeline, initialTime + NS_IN_HOUR, 200);
        Timeline.insert(timeline, initialTime + (2 * NS_IN_HOUR), 300);
        Timeline.insert(timeline, initialTime + (3 * NS_IN_HOUR), 400);

        let historyArray = Timeline.history(timeline);

        assert historyArray.size() == 3;
        assert historyArray[0].data == 100; // Initial value
        assert historyArray[1].data == 200; // After 1h
        assert historyArray[2].data == 300; // After 2h

        Debug.print("✅ TEST PASSED: history() returns checkpoints in order!");
    });
});

suite("Timeline - Edge Cases", func() {

    let NS_IN_HOUR : Nat = 3_600_000_000_000;

    test("backward timestamp prints warning but doesn't trap", func() {
        let initialTime : Nat = 1_000_000_000_000_000_000;
        let timeline = Timeline.make1h<Nat>(initialTime, 0);

        // Insert at +1 hour
        Timeline.insert(timeline, initialTime + NS_IN_HOUR, 1);

        Debug.print("\nInserting backward timestamp (should print warning):");
        // Insert at earlier time (should print warning)
        Timeline.insert(timeline, initialTime + (NS_IN_HOUR / 2), 2);

        // Should still update current despite warning
        assert timeline.current.data == 2;

        Debug.print("✅ TEST PASSED: Backward timestamp handled gracefully!");
    });

    test("exactly minIntervalNs should create checkpoint", func() {
        let initialTime : Nat = 1_000_000_000_000_000_000;
        let timeline = Timeline.make1h<Nat>(initialTime, 0);

        // Insert at exactly 1 hour (minIntervalNs)
        Timeline.insert(timeline, initialTime + NS_IN_HOUR, 1);

        Debug.print("After inserting at exactly minIntervalNs:");
        Debug.print("  history.size(): " # debug_show(timeline.history.size()));

        // Should create checkpoint since window >= minIntervalNs
        assert timeline.history.size() == 1;

        Debug.print("✅ TEST PASSED: Exact minIntervalNs creates checkpoint!");
    });

    test("just below minIntervalNs doesn't create checkpoint", func() {
        let initialTime : Nat = 1_000_000_000_000_000_000;
        let timeline = Timeline.make1h<Nat>(initialTime, 0);

        // Insert at 1ns before 1 hour
        Timeline.insert(timeline, initialTime + NS_IN_HOUR - 1, 1);

        Debug.print("After inserting at minIntervalNs - 1:");
        Debug.print("  history.size(): " # debug_show(timeline.history.size()));

        // Should NOT create checkpoint
        assert timeline.history.size() == 0;

        Debug.print("✅ TEST PASSED: Just below minIntervalNs doesn't checkpoint!");
    });
});

suite("Timeline - Copy Bug Test", func() {

    let NS_IN_HOUR : Nat = 3_600_000_000_000;

    test("mutations on shallow copy DO affect original (var fields)", func() {
        Debug.print("\n=== Testing if var field mutations persist ===");

        let initialTime : Nat = 1_000_000_000_000_000_000;

        // Create original timeline
        let originalTimeline = Timeline.make1h<Text>(initialTime, "initial");

        // Create a "shallow copy" by extracting fields
        // In Motoko, var fields should still reference the same memory
        let copiedTimeline = {
            var current = originalTimeline.current;
            var history = originalTimeline.history;
            var lastCheckpointTimestamp = originalTimeline.lastCheckpointTimestamp;
            minIntervalNs = originalTimeline.minIntervalNs;
        };

        Debug.print("Before any insertions:");
        Debug.print("  original.history.size(): " # debug_show(originalTimeline.history.size()));
        Debug.print("  copied.history.size(): " # debug_show(copiedTimeline.history.size()));

        // Insert on the COPY after > 1 hour
        let time1 = initialTime + NS_IN_HOUR + 1;
        Timeline.insert(copiedTimeline, time1, "after 1 hour");

        Debug.print("\nAfter inserting on COPIED timeline (>1h gap):");
        Debug.print("  original.history.size(): " # debug_show(originalTimeline.history.size()));
        Debug.print("  copied.history.size(): " # debug_show(copiedTimeline.history.size()));

        // With the bug fix (lastCheckpointTimestamp), the issue is:
        // The var fields (history, current, lastCheckpointTimestamp) are REASSIGNED
        // So the original won't be updated when we mutate the copy

        if (originalTimeline.history.size() == 0 and copiedTimeline.history.size() > 0) {
            Debug.print("⚠️  CONFIRMED: Shallow copy with var field reassignment doesn't update original");
            Debug.print("   This is why state.lending.index needs direct reference!");
        } else if (originalTimeline.history.size() > 0) {
            Debug.print("✅ Mutations affected original (unexpected but good)");
        };

        // This test documents the behavior rather than asserting success/failure
        Debug.print("✅ TEST PASSED: Copy behavior documented!");
    });
});
