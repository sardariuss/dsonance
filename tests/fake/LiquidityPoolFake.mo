//import Types "../../src/protocol/lending/Types";
//
//import Float "mo:base/Float";
//import Int "mo:base/Int";
//import LedgerAccountFake "LedgerAccountFake";
//import Debug "mo:base/Debug";
//
//module {
//
//    type ILiquidityPool = Types.ILiquidityPool;
//
//    public class LiquidityPoolFake({
//        start_price: Float;
//    }) : ILiquidityPool {
//
//        var price : Float = start_price;
//
//        public func set_price(new_price: Float) {
//            price := new_price;
//        };
//
//        public func get_collateral_spot_in_asset(_: { time: Nat }) : Float {
//            price;
//        };
//
//        public func swap_collateral(args: { amount: Nat }) : Nat {
//            Int.abs(Float.toInt(Float.fromInt(args.amount) * price));
//        };
//
//    };
//
//}
