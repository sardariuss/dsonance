import Types "Types";

import Timer "mo:base/Timer";
import Result "mo:base/Result";
import Principal "mo:base/Principal";

module {

    type Result<Ok, Err> = Result.Result<Ok, Err>;

    type TimerParameters = Types.TimerParameters;

    type ProtocolTimerArgs = {
        admin: Principal;
        var parameters: TimerParameters;
    };

    public class ProtocolTimer(args: ProtocolTimerArgs) {

        let { admin; } = args;
        var _id: ?Nat = null;

        public func set_timer({ caller: Principal; parameters: TimerParameters; }) : async* Result<(), Text> {
            if (not Principal.equal(caller, admin)) {
                return #err("Only the admin can set the timer");
            };
            if (_id != null) {
                return #err("Cannot set the timer type while it is running");
            };
            args.parameters := parameters;
            #ok;
        };

        public func start_timer({ caller: Principal; fn: () -> async*() }) : async* Result<(), Text> {
            if (not Principal.equal(caller, admin)) {
                return #err("Only the admin can set the timer");
            };
            if (_id != null) {
                return #err("The timer is already running");
            };
            _id := switch(args.parameters) {
                case(#SINGLE_SHOT({duration_s})) {
                    ?Timer.setTimer<system>(#seconds(duration_s), func() : async () {
                        await* fn();
                        _id := null;
                    });
                };
                case(#RECURRING({interval_s})) {
                    ?Timer.recurringTimer<system>(#seconds(interval_s), func() : async () {
                        await* fn();
                    });
                };
            };
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