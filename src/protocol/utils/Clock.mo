import Duration "../duration/Duration";
import Types "../Types";

import Int "mo:base/Int";
import Time "mo:base/Time";
import Float "mo:base/Float";
import Result "mo:base/Result";

module {

    type Duration = Duration.Duration;
    type Time = Int;
    type Result<Ok, Err> = Result.Result<Ok, Err>;

    type ClockParameters = Types.ClockParameters;
    type ClockInfo = Types.ClockInfo;

    public class Clock(params: ClockParameters) {

        public func get_parameters() : ClockParameters {
            params;
        };

        public func clock_info() : ClockInfo {
            {
                time = get_time();
                dilation_factor = switch(params){
                    case(#REAL) { 1.0; };
                    case(#SIMULATED(p)) { p.dilation_factor; };
                };
            };
        };

        public func add_offset(duration: Duration) : Result<(), Text> {
            let p = switch(params){
                case(#REAL) { return #err("Cannot add offset to real clock"); };
                case(#SIMULATED(p)) { p; };
            };
            p.offset_ns += Int.abs(Duration.toTime(duration));
            #ok;
        };

        public func set_dilation_factor(dilation_factor: Float) : Result<(), Text> {
            let p = switch(params){
                case(#REAL) { return #err("Cannot set dilation factor to real clock"); };
                case(#SIMULATED(p)) { p; };
            };
            let now = Time.now();
            // First add the current dilation to the offset
            p.offset_ns += compute_dilatation(now, p.time_ref, p.dilation_factor);
            // Then update the time reference with the current time
            p.time_ref := now;
            // Then update the dilation factor
            p.dilation_factor := dilation_factor;
            #ok;
        };

        public func get_time() : Time {
            let now = Time.now();
            switch(params){
                case(#REAL) { now; };
                case(#SIMULATED(p)) { p.time_ref + compute_dilatation(now, p.time_ref, p.dilation_factor) + p.offset_ns; };
            };
        };

        func compute_dilatation(now: Time, time_ref: Time, dilation_factor: Float) : Time {
            let time_diff = now - time_ref;
            Float.toInt(Float.fromInt(time_diff) * dilation_factor);
        };

    };

};