import Types "../../src/protocol/lending/Types";

module {

    type ILiquidityPool = Types.ILiquidityPool;

    public class LiquidityPoolFake(price: Nat) : ILiquidityPool {

        public func get_collateral_spot_in_asset(_: { time: Nat }) : Nat {
            price;
        };

        public func swap_collateral(args: { amount: Nat }) : Nat {
            args.amount * price;
        };

    };

}
