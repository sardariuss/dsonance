import Types "../Types";

import Result "mo:base/Result";
import Array "mo:base/Array";
import Debug "mo:base/Debug";

module {

  type Result<Ok, Err> = Result.Result<Ok, Err>;

  type Timeline<T> = Types.Timeline<T>;

  public type TimedData<T> = {
    timestamp: Nat;
    data: T;
  };

  // Initialize the history with the first entry
  public func initialize<T>(timestamp: Nat, data: T): Timeline<T> {
    {
      var current = { timestamp; data };
      var history = [];
    }
  };

  public func deepCopy<T>(timeline: Timeline<T>): Timeline<T> {
    {
      var current = { timestamp = timeline.current.timestamp; data = timeline.current.data };
      var history = Array.map<TimedData<T>, TimedData<T>>(timeline.history, func(entry) {
        { timestamp = entry.timestamp; data = entry.data }
      });
    }
  };

  // Insert a new entry
  public func insert<T>(timeline: Timeline<T>, timestamp: Nat, data: T) {
    if (timestamp < timeline.current.timestamp) {
      Debug.trap("The timestamp must be greater than or equal to the current timestamp");
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
