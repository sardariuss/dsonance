import MockTypes "MockTypes";
import BaseMock "BaseMock";
import Interfaces "../../src/protocol/utils/Clock";

module {

    public type Method = {
        #get_time;
    };

    public type Return = {
        #get_time: {
            #returns: Nat;
        };
    };

    public class ClockMock() : Interfaces.IClock and MockTypes.IMock<Return> {

        let base = BaseMock.BaseMock<Return, Method>({
            to_text = func(arg: Method) : Text {
                switch(arg){
                    case(#get_time) { "get_time"; };
                };
            };
            from_return = func(args: Return) : Method {
                switch(args){
                    case(#get_time(_)) { #get_time; };
                };
            };
            method_hash = (
                func(m: Method) : Nat32 {
                    switch(m){
                        case(#get_time) { 1; };
                    };
                },
                func (m1: Method, m2: Method) : Bool {
                    switch(m1, m2){
                        case(#get_time, #get_time) { true };
                    };
                }
            )
        });

        public func get_time() : Nat {
            let arg = base.next_call(#get_time);
            switch(arg){
                case(#get_time(#returns(value))) {
                    return value;
                };
            };
        };

        public func expect_call(arg: Return, times: MockTypes.Times) {
            base.expect_call(arg, times);
        };

        public func teardown() {
            base.teardown();
        };

    };

}
