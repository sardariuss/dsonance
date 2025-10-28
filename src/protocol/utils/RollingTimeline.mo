import Result "mo:base/Result";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";

module {

  type Result<Ok, Err> = Result.Result<Ok, Err>;

  public type TimedData<T> = {
    timestamp: Nat;
    data: T;
  };

  public type RollingTimeline<T> = {
    var current: TimedData<T>;
    history: [var ?TimedData<T>];
    var lastCheckpointTimestamp: Nat;
    var index: Nat;
    maxSize: Nat;
    minIntervalNs: Nat; // in nanoseconds, e.g. 5 min = 300_000_000_000
  };

  /// Create a new timeline with given window and max history size.
  public func make<T>(timestamp: Nat, data: T, minIntervalNs: Nat, maxSize: Nat): RollingTimeline<T> {
    {
      var current = { timestamp; data };
      history = Array.init<?TimedData<T>>(maxSize, null);
      var lastCheckpointTimestamp = timestamp;
      var index = 0;
      maxSize;
      minIntervalNs;
    };
  };

  /// Helper for a 1 hour interval and 4 year history (35,040 entries)
  public func make1h4y<T>(timestamp: Nat, data: T): RollingTimeline<T> {
    make<T>(timestamp, data, 60 * 60_000_000_000, 35_040);
  };

  /// Insert a new entry, respecting batching and ring size
  public func insert<T>(timeline: RollingTimeline<T>, timestamp: Nat, data: T) {

    let window : Int = timestamp - timeline.lastCheckpointTimestamp;

    // TODO: return an error or trap?
    if (window < 0) {
      Debug.print("WARNING: RollingTimeline insert: timestamp is " # debug_show(window) # " ns older than last checkpoint timestamp");
    };

    // If within the current window, overwrite current
    if (window < timeline.minIntervalNs) {
      timeline.current := { timestamp; data };
      return;
    };

    // Otherwise push the current into ring buffer and update checkpoint
    timeline.history[timeline.index] := ?timeline.current;
    timeline.index := (timeline.index + 1) % timeline.maxSize;
    timeline.lastCheckpointTimestamp := timestamp;
    timeline.current := { timestamp; data };
  };

  /// Retrieve the latest data
  public func current<T>(timeline: RollingTimeline<T>): T {
    timeline.current.data;
  };

  /// Get the non-null historical entries as an array (oldest to newest)
  public func history<T>(timeline: RollingTimeline<T>): [TimedData<T>] {
    var buf : [TimedData<T>] = [];
    for (i in Iter.range(0, timeline.maxSize - 1)) {
      let idx = (timeline.index + i) % timeline.maxSize;
      switch (timeline.history[idx]) {
        case (?entry) { buf := Array.append(buf, [entry]); };
        case (null) {};
      };
    };
    buf;
  };

};
