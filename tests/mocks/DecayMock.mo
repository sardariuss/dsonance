import MockTypes "MockTypes";
import BaseMock "BaseMock";
import Interfaces "../../src/protocol/Interfaces";
import Types "../../src/protocol/Types";

import Debug "mo:base/Debug";

module {

    type Time = Int;
    type Decayed = Types.Decayed;

    public type Method = {
        #compute_decay;
        #create_decayed;
        #unwrap_decayed;
    };

    public type Return = {
        #compute_decay: {
            #returns: Float;
        };
        #create_decayed: {
            #returns: Decayed;
        };
        #unwrap_decayed: {
            #returns: Float;
        };
    };

    public class DecayMock() : Interfaces.IDecayModel and MockTypes.IMock<Return> {

        let base = BaseMock.BaseMock<Return, Method>({
            to_text = func(arg: Method) : Text {
                switch(arg){
                    case(#compute_decay) { "compute_decay"; };
                    case(#create_decayed) { "create_decayed"; };
                    case(#unwrap_decayed) { "unwrap_decayed"; };
                };
            };
            from_return = func(args: Return) : Method {
                switch(args){
                    case(#compute_decay(_)) { #compute_decay; };
                    case(#create_decayed(_)) { #create_decayed; };
                    case(#unwrap_decayed(_)) { #unwrap_decayed; };
                };
            };
            method_hash = (
                func(m: Method) : Nat32 {
                    switch(m){
                        case(#compute_decay) { 1; };
                        case(#create_decayed) { 2; };
                        case(#unwrap_decayed) { 3; };
                    };
                },
                func (m1: Method, m2: Method) : Bool {
                    switch(m1, m2){
                        case(#compute_decay, #compute_decay) { true };
                        case(#create_decayed, #create_decayed) { true };
                        case(#unwrap_decayed, #unwrap_decayed) { true };
                        case(_, _) { false };
                    };
                }
            )
        });

        public func compute_decay(_: Nat) : Float {
            let arg = base.next_call(#compute_decay);
            switch(arg){
                case(#compute_decay(#returns(value))) {
                    return value;
                };
                case(_) {
                    Debug.trap("Unexpected argument for compute_decay!");
                };
            };
        };

        public func create_decayed(_: Float, _: Nat) : Decayed {
            let arg = base.next_call(#create_decayed);
            switch(arg){
                case(#create_decayed(#returns(value))) {
                    return value;
                };
                case(_) {
                    Debug.trap("Unexpected argument for create_decayed!");
                };
            };
        };

        public func unwrap_decayed(_: Decayed, _: Nat) : Float {
            let arg = base.next_call(#unwrap_decayed);
            switch(arg){
                case(#unwrap_decayed(#returns(value))) {
                    return value;
                };
                case(_) {
                    Debug.trap("Unexpected argument for unwrap_decayed!");
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