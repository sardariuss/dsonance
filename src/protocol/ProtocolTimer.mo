import Types "Types";

import Timer "mo:base/Timer";
import Result "mo:base/Result";
import Principal "mo:base/Principal";

module {

    type TimerParameters = Types.TimerParameters;
    type Result<Ok, Err> = Result.Result<Ok, Err>;

    public class ProtocolTimer({
        admin: Principal; 
    }) {

        var _parameters: ?TimerParameters = null;

        public func get_timer() : ?TimerParameters {
            _parameters;
        };

        public func set_timer({ caller: Principal; duration_s: Nat; fn: () -> async*() }) : async* Result<(), Text> {
            if (not Principal.equal(caller, admin)) {
                return #err("Only the admin can set the timer");
            };
            // Restart the timer
            ignore stop_timer({caller});
            let id = Timer.recurringTimer<system>(#seconds(duration_s), func() : async () {
                await* fn();
            });
            _parameters := ?{ id; duration_s; };
            #ok;
        };

        public func stop_timer({ caller: Principal }) : Result<(), Text> {
            if (not Principal.equal(caller, admin)) {
                return #err("Only the admin can stop the timer");
            };
            switch(_parameters) {
                case(?{id}) { Timer.cancelTimer(id); _parameters := null; };
                case(null) {};
            };
            #ok;
        };
    };
};