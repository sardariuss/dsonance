import Types "Types";

import Timer "mo:base/Timer";
import Result "mo:base/Result";
import Principal "mo:base/Principal";

module {

    type TimerParameters = Types.TimerParameters;
    type Result<Ok, Err> = Result.Result<Ok, Err>;

    public class ProtocolTimer({
        admin: Principal;
        parameters: TimerParameters;
    }) {

        var _id: ?Nat = null;

        public func set_interval({ caller: Principal; interval_s: Nat; }) : async* Result<(), Text> {
            if (not Principal.equal(caller, admin)) {
                return #err("Only the admin can set the timer");
            };
            if (_id != null) {
                return #err("Cannot set the timer duration while it is running");
            };
            parameters.interval_s := interval_s;
            #ok;
        };

        public func start_timer({ caller: Principal; fn: () -> async*() }) : async* Result<(), Text> {
            if (not Principal.equal(caller, admin)) {
                return #err("Only the admin can set the timer");
            };
            if (_id != null) {
                return #err("The timer is already running");
            };
            _id := ?Timer.recurringTimer<system>(#seconds(parameters.interval_s), func() : async () {
                await* fn();
            });
            #ok;
        };

        public func stop_timer({ caller: Principal }) : Result<(), Text> {
            if (not Principal.equal(caller, admin)) {
                return #err("Only the admin can stop the timer");
            };
            switch(_id) {
                case(null) {
                    return #err("The timer is already stopped");
                };
                case(?id) {
                    Timer.cancelTimer(id);
                    _id := null;
                };
            };
            #ok;
        };
    };
};