import MockTypes "MockTypes";

import Deque "mo:base/Deque";
import Debug "mo:base/Debug";
import Option "mo:base/Option";

import Map "mo:map/Map";

module {

    type IMock<R> = MockTypes.IMock<R>;
    type Times = MockTypes.Times;

    type CallsLeft<R> = {
        returns: R;
        var calls_left: Nat;
    };

    // Consume a call, decrementing the number of calls left.
    // Returns true if there are still calls left, false otherwise.
    func consume_call<R>(config: CallsLeft<R>) : Bool {
        if (config.calls_left == 0) {
            Debug.trap("Unexpected call to method, no calls left!");
        };
        config.calls_left := (config.calls_left - 1);
        config.calls_left > 0;
    };

    public class BaseMock<R, M>({
        to_text: M -> Text;
        from_return: R -> M;
        method_hash: Map.HashUtils<M>;
    }) : IMock<R> {

        let numbered_calls = Map.new<M, Deque.Deque<CallsLeft<R>>>();
        let repeated_calls = Map.new<M, R>();

        public func expect_call(arg: R, times: Times) {
            let method = from_return(arg);
            switch(times) {
                case(#repeatedly) {
                    Map.set(repeated_calls, method_hash, method, arg);
                };
                case(#times(n)) {
                    // Overwrite the repeated calls if any
                    Map.delete(repeated_calls, method_hash, method);

                    let deque = Option.get(Map.get(numbered_calls, method_hash, method), Deque.empty<CallsLeft<R>>());
                    if (n == 0) {
                        Debug.trap("Cannot configure a call with 0 times!");
                    };
                    Map.set(numbered_calls, method_hash, method, Deque.pushBack(deque, { returns = arg; var calls_left = n }));
                };
            };
        };

        public func next_call(method: M) : R {
            switch(Map.get(numbered_calls, method_hash, method)){
                case(?deque) {
                    switch(Deque.popFront(deque)) {
                        case(null) { 
                            Debug.trap("Logic error: empty deque should have been deleted!");
                        };
                        case(?(head, tail)) {
                            if (not consume_call(head)){
                                if (Deque.isEmpty(tail)){
                                    Map.delete(numbered_calls, method_hash, method);
                                } else {
                                    Map.set(numbered_calls, method_hash, method, tail);
                                };
                            };
                            return head.returns;
                        };
                    };
                };
                case(null) {};
            };

            switch(Map.get(repeated_calls, method_hash, method)){
                case(null) {
                    Debug.trap("Unexpected call to " # to_text(method) # ", no expectation set!");
                };
                case(?returns) { returns; };
            };
        };

        public func teardown() {
            for ((method, deque) in Map.entries(numbered_calls)){
                Debug.print("Expected call to " # to_text(method) # " was never made.");
            };
        };
    };
    
};