import Debug "mo:base/Debug";

import MockTypes "MockTypes";
import BaseMock "BaseMock";
import LendingTypes "../../src/protocol/lending/Types";

module {

    type ILiquidityPool = LendingTypes.ILiquidityPool;

    public type Method = {
        #get_collateral_spot_in_asset;
        #swap_collateral;
    };

    public type Return = {
        #get_collateral_spot_in_asset: {
            #returns: Nat;
        };
        #swap_collateral: {
            #returns: Nat;
        };
    };

    public class LiquidityPoolMock() : ILiquidityPool and MockTypes.IMock<Return> {

        let base = BaseMock.BaseMock<Return, Method>({
            to_text = func(arg: Method) : Text {
                switch(arg){
                    case(#get_collateral_spot_in_asset) { "get_collateral_spot_in_asset"; };
                    case(#swap_collateral) { "swap_collateral"; };
                };
            };
            from_return = func(args: Return) : Method {
                switch(args){
                    case(#get_collateral_spot_in_asset(_)) { #get_collateral_spot_in_asset; };
                    case(#swap_collateral(_)) { #swap_collateral; };
                };
            };
            method_hash = (
                func(m: Method) : Nat32 {
                    switch(m){
                        case(#get_collateral_spot_in_asset) { 1; };
                        case(#swap_collateral) { 2; };
                    };
                },
                func (m1: Method, m2: Method) : Bool {
                    switch(m1, m2){
                        case(#get_collateral_spot_in_asset, #get_collateral_spot_in_asset) { true };
                        case(#swap_collateral, #swap_collateral) { true };
                        case(_, _) { false };
                    };
                }
            )
        });

        public func get_collateral_spot_in_asset(_: { time: Nat }) : Nat {
            switch(base.next_call(#get_collateral_spot_in_asset)){
                case(#get_collateral_spot_in_asset(#returns(value))) {
                    return value;
                };
                case(_) {
                    Debug.trap("Unexpected argument for get_collateral_spot_in_asset!");
                };
            };
        };

        public func swap_collateral(_: { amount: Nat }) : Nat {
            switch(base.next_call(#swap_collateral)){
                case(#swap_collateral(#returns(value))) {
                    return value;
                };
                case(_) {
                    Debug.trap("Unexpected argument for swap_collateral!");
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
