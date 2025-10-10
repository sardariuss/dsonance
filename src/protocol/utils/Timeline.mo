import Result "mo:base/Result";
import Array "mo:base/Array";
import Debug "mo:base/Debug";

module {

  type Result<Ok, Err> = Result.Result<Ok, Err>;

  public type TimedData<T> = {
    timestamp: Nat;
    data: T;
  };

  public type Timeline<T> = {
    var current: TimedData<T>;
    var history: [TimedData<T>];
    minIntervalNs: Nat;
  };

  public func make<T>(timestamp: Nat, data: T, minIntervalNs: Nat): Timeline<T> {
    {
      var current = { timestamp; data };
      var history = [];
      minIntervalNs;
    }
  };

  public func make1h<T>(timestamp: Nat, data: T): Timeline<T> {
    make<T>(timestamp, data, 60 * 60_000_000_000);
  };

  // Insert a new entry
  public func insert<T>(timeline: Timeline<T>, timestamp: Nat, data: T) {
    if (timestamp < timeline.current.timestamp) {
      Debug.trap("The timestamp must be greater than or equal to the current timestamp");
    };

    // If within the current window, overwrite current
    let window : Int = timestamp - timeline.current.timestamp;
    if (window < timeline.minIntervalNs) {
      timeline.current := { timestamp; data };
      return;
    };
    timeline.history := Array.append(timeline.history, [timeline.current]);
    timeline.current := { timestamp; data };
  };

  // Retrieve the latest entry
  public func current<T>(timeline: Timeline<T>): T {
    timeline.current.data;
  };

  // Retrieve the entire historical log
  public func history<T>(timeline: Timeline<T>): [TimedData<T>] {
    timeline.history;
  };

};