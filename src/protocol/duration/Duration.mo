import Types "../Types";

import Float "mo:base/Float";

module {

    public type Duration = Types.Duration;

    public let NS_IN_YEAR = 31_557_600_000_000_000; // 365.25 * 24 * 60 * 60 * 1_000_000_000
    public let NS_IN_DAY = 86_400_000_000_000; // 24 * 60 * 60 * 1_000_000_000
    public let NS_IN_HOUR = 3_600_000_000_000; // 60 * 60 * 1_000_000_000
    public let NS_IN_MINUTE = 60_000_000_000; // 60 * 1_000_000_000
    public let NS_IN_SECOND = 1_000_000_000;
  
    public func toTime(duration: Duration) : Nat {
        switch (duration) {
            case (#YEARS(years)) { NS_IN_YEAR * years; };
            case (#DAYS(days)) { NS_IN_DAY * days; };
            case (#HOURS(hours)) { NS_IN_HOUR * hours; };
            case (#MINUTES(minutes)) { NS_IN_MINUTE * minutes; };
            case (#SECONDS(seconds)) { NS_IN_SECOND * seconds; };
            case (#NS(ns)) { ns; };
        };
    };


    public func fromTime(time: Nat) : Duration {
        let time_float = Float.fromInt(time);
        if (Float.rem(time_float,  Float.fromInt(NS_IN_YEAR)) == 0.0){
            return #DAYS(time / NS_IN_YEAR);
        };
        if (Float.rem(time_float, Float.fromInt(NS_IN_DAY)) == 0.0){
            return #DAYS(time / NS_IN_DAY);
        };
        if(Float.rem(time_float, Float.fromInt(NS_IN_HOUR)) == 0.0){
            return #HOURS(time / NS_IN_HOUR);
        };
        if(Float.rem(time_float, Float.fromInt(NS_IN_MINUTE)) == 0.0){
            return #MINUTES(time / NS_IN_MINUTE);
        };
        if(Float.rem(time_float, Float.fromInt(NS_IN_SECOND)) == 0.0){
            return #SECONDS(time / NS_IN_SECOND);
        };
        return #NS(time);
    };
}