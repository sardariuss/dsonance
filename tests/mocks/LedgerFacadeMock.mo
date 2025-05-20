import MockTypes "MockTypes";
import BaseMock "BaseMock";
import PayementTypes "../../src/protocol/payement/Types";

import Debug "mo:base/Debug";

module {

    type Time = Int;

    type ILedgerFacade      = PayementTypes.ILedgerFacade;
    type TransferFromArgs   = PayementTypes.TransferFromArgs;
    type TransferArgs       = PayementTypes.TransferArgs;
    type Transfer           = PayementTypes.Transfer;
    type TransferFromResult = PayementTypes.TransferFromResult;

    public type Method = {
        #transfer_from;
        #transfer;
    };

    public type Return = {
        #transfer_from: {
            #returns: TransferFromResult;
        };
        #transfer: {
            #returns: Transfer;
        };
    };

    public class LedgerFacadeMock() : ILedgerFacade and MockTypes.IMock<Return> {

        let base = BaseMock.BaseMock<Return, Method>({
            to_text = func(arg: Method) : Text {
                switch(arg){
                    case(#transfer_from) { "transfer_from"; };
                    case(#transfer) { "transfer"; };
                };
            };
            from_return = func(args: Return) : Method {
                switch(args){
                    case(#transfer_from(_)) { #transfer_from; };
                    case(#transfer(_))      { #transfer;      };
                };
            };
            method_hash = (
                func(m: Method) : Nat32 {
                    switch(m){
                        case(#transfer_from) { 1; };
                        case(#transfer)      { 2; };
                    };
                },
                func (m1: Method, m2: Method) : Bool {
                    switch(m1, m2){
                        case(#transfer_from, #transfer_from) { true  };
                        case(#transfer, #transfer)           { true  };
                        case(_, _)                           { false };
                    };
                }
            )
        });

        public func transfer_from(_: TransferFromArgs) : async* TransferFromResult {
            switch(base.next_call(#transfer_from)){
                case(#transfer_from(#returns(value))) {
                    return value;
                };
                case(_) {
                    Debug.trap("Unexpected argument for transfer_from!");
                };
            };
        };

        public func transfer(_: TransferArgs) : async* Transfer {
            switch(base.next_call(#transfer)){
                case(#transfer(#returns(value))) {
                    return value;
                };
                case(_) {
                    Debug.trap("Unexpected argument for transfer!");
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