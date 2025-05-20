import MockTypes "MockTypes";

import Deque "mo:base/Deque";
import Debug "mo:base/Debug";
import Option "mo:base/Option";

import Map "mo:map/Map";

module {

    type IMock<R> = MockTypes.IMock<R>;
    type Times = MockTypes.Times;

    type CallConfig<R> = {
        returns: R;
        var calls_left: ?Nat;
    };

    func build_config<R>(arg: R, times: Times) : CallConfig<R> {
        let calls_left = switch(times) {
            case(#once)       { ?1;   };
            case(#times(n))   { 
                if (n == 0) {
                    Debug.trap("Cannot configure a call with 0 times!");
                };
                ?n;
            };
            case(#repeatedly) { null; };
        };
        { returns = arg; var calls_left = calls_left; };
    };

    // Consume a call, decrementing the number of calls left.
    // Returns true if there are still calls left, false otherwise.
    func consume_call<R>(config: CallConfig<R>) : Bool {
        switch(config.calls_left) {
            case(?n) {
                if (n == 0) {
                    Debug.trap("Unexpected call to method, no calls left!");
                };
                config.calls_left := ?(n - 1);
                n > 0;
            };
            case(_) { true; };
        };
    };

    public class BaseMock<R, M>({
        to_text: M -> Text;
        from_return: R -> M;
        method_hash: Map.HashUtils<M>;
    }) : IMock<R> {

        let expected_calls = Map.new<M, Deque.Deque<CallConfig<R>>>();

        public func expect_call(arg: R, times: Times) {
            let method = from_return(arg);
            let deque = Option.get(Map.get(expected_calls, method_hash, method), Deque.empty<CallConfig<R>>());
            Map.set(expected_calls, method_hash, method, Deque.pushBack(deque, build_config(arg, times)));
        };

        public func next_call(method: M) : R {
            switch(Map.get(expected_calls, method_hash, method)){
                case(?deque) {
                    switch(Deque.popFront(deque)) {
                        case(?(head, tail)) {
                            if (not consume_call(head)){
                                if (Deque.isEmpty(tail)){
                                    Map.delete(expected_calls, method_hash, method);
                                } else {
                                    Map.set(expected_calls, method_hash, method, tail);
                                };
                            };
                            return head.returns;
                        };
                        case(_) { 
                            Debug.trap("Unexpected call to " # to_text(method) # ": Empty deque!");
                        };
                    };
                };
                case(_) {
                    Debug.trap("Unexpected call to " # to_text(method) # ": No deque found!");
                };
            };
        };

        public func teardown() {
            for ((method, deque) in Map.entries(expected_calls)){
                Debug.print("Expected call to " # to_text(method) # " was never made.");
            };
        };
    };
    
};