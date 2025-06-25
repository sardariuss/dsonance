import MockTypes "MockTypes";
import BaseMock "BaseMock";
import LedgerTypes "../../src/protocol/ledger/Types";

import Debug "mo:base/Debug";

module {

    type Time = Int;

    type ILedgerAccount      = LedgerTypes.ILedgerAccount;
    type TransferFromArgs   = LedgerTypes.TransferFromArgs;
    type TransferArgs       = LedgerTypes.TransferArgs;
    type Transfer           = LedgerTypes.Transfer;
    type TransferFromResult = LedgerTypes.TransferFromResult;

    public type Method = {
        #transfer_from;
        #transfer;
        #add_balance;
        #get_balance;
    };

    public type Return = {
        #transfer_from: {
            #returns: TransferFromResult;
        };
        #transfer: {
            #returns: Transfer;
        };
        #add_balance: {
            #returns: ();
        };
        #get_balance: {
            #returns: Nat;
        };
    };

    public class LedgerAccountMock() : ILedgerAccount and MockTypes.IMock<Return> {

        let base = BaseMock.BaseMock<Return, Method>({
            to_text = func(arg: Method) : Text {
                switch(arg){
                    case(#transfer_from) { "transfer_from"; };
                    case(#transfer) { "transfer"; };
                    case(#add_balance) { "add_balance"; };
                    case(#get_balance) { "get_balance"; };
                };
            };
            from_return = func(args: Return) : Method {
                switch(args){
                    case(#transfer_from(_)) { #transfer_from; };
                    case(#transfer(_))      { #transfer;      };
                    case(#add_balance(_))  { #add_balance;   };
                    case(#get_balance(_))  { #get_balance;   };
                };
            };
            method_hash = (
                func(m: Method) : Nat32 {
                    switch(m){
                        case(#transfer_from) { 1; };
                        case(#transfer)      { 2; };
                        case(#add_balance)   { 3; };
                        case(#get_balance)   { 4; };
                    };
                },
                func (m1: Method, m2: Method) : Bool {
                    switch(m1, m2){
                        case(#transfer_from, #transfer_from) { true  };
                        case(#transfer, #transfer)           { true  };
                        case(#add_balance, #add_balance)     { true  };
                        case(#get_balance, #get_balance)     { true  };
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

        public func add_balance(_: Nat) {
            switch(base.next_call(#add_balance)){
                case(#add_balance(#returns())) {};
                case(_) {
                    Debug.trap("Unexpected argument for add_balance!");
                };
            };
        };

        public func get_balance() : Nat {
            switch(base.next_call(#get_balance)){
                case(#get_balance(#returns(value))) {
                    return value;
                };
                case(_) {
                    Debug.trap("Unexpected argument for get_balance!");
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