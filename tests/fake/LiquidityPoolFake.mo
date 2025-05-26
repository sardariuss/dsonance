import Types "../../src/protocol/lending/Types";

import Float "mo:base/Float";
import Int "mo:base/Int";
import LedgerFacadeFake "LedgerFacadeFake";

module {

    type ILiquidityPool = Types.ILiquidityPool;

    public class LiquidityPoolFake({
        start_price: Float;
        supply_ledger: LedgerFacadeFake.LedgerFacadeFake;
        collateral_ledger: LedgerFacadeFake.LedgerFacadeFake;
    }) : ILiquidityPool {

        var price : Float = start_price;

        public func set_price(new_price: Float) {
            price := new_price;
        };

        public func get_collateral_spot_in_asset(_: { time: Nat }) : Float {
            price;
        };

        public func swap_collateral(args: { amount: Nat }) : Nat {
            let asset_amount = Int.abs(Float.toInt(Float.fromInt(args.amount) * price));
            collateral_ledger.sub_balance(args.amount);
            supply_ledger.add_balance(asset_amount);
            asset_amount;
        };

    };

}
