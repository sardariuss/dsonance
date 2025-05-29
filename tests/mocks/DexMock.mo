import MockTypes "MockTypes";
import BaseMock "BaseMock";
import LedgerType "../../src/protocol/ledger/Types";
import Debug "mo:base/Debug";

module {
    public type Method = {
        #swap_amounts : (Text, Nat, Text);
        #swap : LedgerType.SwapArgs;
        #last_price : LedgerType.PriceArgs;
    };

    public type Return = {
        #swap_amounts: {
            #returns: LedgerType.SwapAmountsResult;
        };
        #swap :{
            #returns:  LedgerType.SwapResult;
        };
        #last_price :{
            #returns:  Float;
        };
    };

    public class DexMock() : LedgerType.IDex and MockTypes.IMock<Return> {
        let base = BaseMock.BaseMock<Return, Method>({
            to_text = func(arg: Method) : Text {
                switch(arg){
                    case(#swap_amounts(_,_,_)) { "swap_amounts" };
                    case(#swap(_)) { "swap" };
                    case(#last_price(_)) { "last_price" };
                }
            };
            from_return = func(args: Return) : Method {
                switch(args){
                    case(#swap_amounts(_)) { #swap_amounts("",0,"") };
                    case(#swap(_)) { #swap({
                        pay_token=""; pay_amount=0; pay_tx_id=null; receive_token=""; receive_amount=null; receive_address=null; max_slippage=null; referred_by=null;
                    }) };
                    case(#last_price(_)) { #last_price({ pay_token=""; receive_token=""; }) };
                }
            };
            method_hash = (
                func(m: Method) : Nat32 {
                    switch(m){
                        case(#swap_amounts(_,_,_)) { 1 };
                        case(#swap(_)) { 2 };
                        case(#last_price(_)) { 3 };
                    }
                },
                func (m1: Method, m2: Method) : Bool {
                    switch(m1, m2){
                        case(#swap_amounts(_,_,_), #swap_amounts(_,_,_)) { true };
                        case(#swap(_),             #swap(_))             { true };
                        case(#last_price(_),       #last_price(_))       { true };
                        case _                                           { false };
                    }
                }
            )
        });

        public func swap_amounts(pay_token: Text, pay_amount: Nat, receive_token: Text) : async* LedgerType.SwapAmountsResult {
            let arg = base.next_call(#swap_amounts(pay_token, pay_amount, receive_token));
            switch(arg){
                case(#swap_amounts(#returns(result))) result;
                case _ Debug.trap("DexMock: Unexpected return for swap_amounts");
            }
        };

        public func swap(args: LedgerType.SwapArgs) : async* LedgerType.SwapResult {
            let arg = base.next_call(#swap(args));
            switch(arg){
                case(#swap(#returns(result))) result;
                case _ Debug.trap("DexMock: Unexpected return for swap");
            }
        };

        public func last_price(args: LedgerType.PriceArgs) : Float {
            let arg = base.next_call(#last_price(args));
            switch(arg){
                case(#last_price(#returns(price))) price;
                case _ Debug.trap("DexMock: Unexpected return for last_price");
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
