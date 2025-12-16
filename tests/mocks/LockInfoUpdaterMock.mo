import MockTypes "MockTypes";
import BaseMock "BaseMock";
import Interfaces "../../src/protocol/Interfaces";
import LockInfoUpdater "../../src/protocol/locks/LockInfoUpdater";

import Map "mo:map/Map";
import Debug "mo:base/Debug";

module {

    type Elem = LockInfoUpdater.Elem;

    public type Method = {
        #add;
    };

    public type Return = {
        #add: {
            #returns;
        };
    };

    public class LockInfoUpdaterMock() : Interfaces.ILockInfoUpdater and MockTypes.IMock<Return> {

        let base = BaseMock.BaseMock<Return, Method>({
            to_text = func(arg: Method) : Text {
                switch(arg){
                    case(#add) { "add"; };
                };
            };
            from_return = func(args: Return) : Method {
                switch(args){
                    case(#add(_)) { #add; };
                };
            };
            method_hash = (
                func(m: Method) : Nat32 {
                    switch(m){
                        case(#add) { 1; };
                    };
                },
                func (m1: Method, m2: Method) : Bool {
                    switch(m1, m2){
                        case(#add, #add) { true };
                    };
                }
            )
        });

        public func add(new: Elem, previous: Map.Iter<Elem>, time: Nat) {
            let arg = base.next_call(#add);
            switch(arg){
                case(#add(#returns)) {
                    return;
                };
                case(_) {
                    Debug.trap("Unexpected argument for add!");
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

};
