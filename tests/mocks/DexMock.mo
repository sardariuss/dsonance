import Debug "mo:base/Debug";
import Result "mo:base/Result";
import Principal "mo:base/Principal";

import MockTypes "MockTypes";
import BaseMock "BaseMock";
import LedgerType "../../src/protocol/ledger/Types";
import KongTypes "../../src/protocol/kong/Types";

module {

    type Result<Ok, Err> = Result.Result<Ok, Err>;

    public type Method = {
        #swap_amounts : (Text, Nat, Text);
        #swap : LedgerType.AugmentedSwapArgs;
        #last_price : KongTypes.PriceArgs;
        #get_main_account;
    };

    public type Return = {
        #swap_amounts: {
            #returns: Result<LedgerType.SwapAmountsReply, Text>;
        };
        #swap :{
            #returns:  Result<LedgerType.SwapReply, Text>;
        };
        #last_price :{
            #returns:  Float;
        };
        #get_main_account : {
            #returns: LedgerType.Account;
        };
    };

    public class DexMock() : LedgerType.IDex and MockTypes.IMock<Return> {
        let base = BaseMock.BaseMock<Return, Method>({
            to_text = func(arg: Method) : Text {
                switch(arg){
                    case(#swap_amounts(_,_,_)) { "swap_amounts" };
                    case(#swap(_)) { "swap" };
                    case(#last_price(_)) { "last_price" };
                    case(#get_main_account) { "get_main_account" };
                }
            };
            from_return = func(args: Return) : Method {
                switch(args){
                    case(#swap_amounts(_)) { #swap_amounts("",0,"") };
                    case(#swap(_)) { #swap({
                        pay_token=""; 
                        pay_amount=0; 
                        pay_tx_id=null; 
                        receive_token=""; 
                        receive_amount=null; 
                        receive_address=null; 
                        max_slippage=null; 
                        referred_by=null; 
                        from={ owner=Principal.fromText("2vxsx-fae"); 
                        subaccount=null; };
                    }) };
                    case(#last_price(_)) { #last_price({ pay_token=""; receive_token=""; }) };
                    case(#get_main_account(_)) { #get_main_account };
                }
            };
            method_hash = (
                func(m: Method) : Nat32 {
                    switch(m){
                        case(#swap_amounts(_,_,_)) { 1 };
                        case(#swap(_)) { 2 };
                        case(#last_price(_)) { 3 };
                        case(#get_main_account) { 4 };
                    }
                },
                func (m1: Method, m2: Method) : Bool {
                    switch(m1, m2){
                        case(#swap_amounts(_,_,_), #swap_amounts(_,_,_)) { true };
                        case(#swap(_),             #swap(_))             { true };
                        case(#last_price(_),       #last_price(_))       { true };
                        case(#get_main_account,    #get_main_account)    { true };
                        case _                                           { false };
                    }
                }
            )
        });

        public func swap_amounts(pay_token: Text, pay_amount: Nat, receive_token: Text) : async* Result<LedgerType.SwapAmountsReply, Text> {
            let arg = base.next_call(#swap_amounts(pay_token, pay_amount, receive_token));
            switch(arg){
                case(#swap_amounts(#returns(result))) result;
                case _ Debug.trap("DexMock: Unexpected return for swap_amounts");
            }
        };

        public func swap(args: LedgerType.AugmentedSwapArgs) : async* Result<LedgerType.SwapReply, Text> {
            let arg = base.next_call(#swap(args));
            switch(arg){
                case(#swap(#returns(result))) result;
                case _ Debug.trap("DexMock: Unexpected return for swap");
            }
        };

        public func get_main_account() : LedgerType.Account {
            let arg = base.next_call(#get_main_account);
            switch(arg){
                case(#get_main_account(#returns(account))) account;
                case _ Debug.trap("DexMock: Unexpected return for get_main_account");
            }
        };

        public func expect_call(arg: Return, times: MockTypes.Times) {
            base.expect_call(arg, times);
        };

        public func teardown() {
            base.teardown();
        };
    };
}
