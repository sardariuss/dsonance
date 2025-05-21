import Result "mo:base/Result";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";

import Map "mo:map/Map";

import InterestRateCurve "InterestRateCurve";
import Math "../utils/Math";
import Types "../Types";
import Duration "../duration/Duration";
import BorrowRegistry "BorrowRegistry";
import SupplyRegistry "SupplyRegistry";
import IterUtils "../utils/Iter";
import LendingTypes "Types";
import Index "Index";

module {

    type Account = Types.Account;
    type TxIndex = Types.TxIndex;
    type Register<T> = Types.Register<T>;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type Transfer = Types.Transfer;
    type Duration = Types.Duration;

    type SupplyPosition      = LendingTypes.SupplyPosition;
    type SupplyInput         = LendingTypes.SupplyInput;
    type BorrowPosition      = LendingTypes.BorrowPosition;
    type RepaymentArgs       = LendingTypes.RepaymentArgs;
    type LendingPoolState    = LendingTypes.LendingPoolState;
    type SellCollateralQuery = LendingTypes.SellCollateralQuery;
    type DebtEntry           = LendingTypes.DebtEntry;
    type AssetAccounting     = LendingTypes.AssetAccounting;
    type Index               = LendingTypes.Index;
    type LendingPoolParameters = LendingTypes.LendingPoolParameters;

    public class LendingPool({
        parameters: LendingPoolParameters;
        state: LendingPoolState;
        borrow_registry: BorrowRegistry.BorrowRegistry;
        supply_registry: SupplyRegistry.SupplyRegistry;
        interest_rate_curve: InterestRateCurve.InterestRateCurve;
        //sell_collateral: SellCollateralQuery;
        //asset_accounting: AssetAccounting;
    }){

        type TotalToLiquidate = {
            borrowed: Float;
            collateral: Float;
        };

// @todo: fix partial liquidation, or use full liquidation for now
//        /// Liquidate borrow positions if their health factor is below 1.0.
//        /// @todo: this function access shall be restricted to the protocol only and called by a timer
//        public func check_all_positions_and_liquidate({ 
//            time: Nat;
//            collateral_spot_in_asset: () -> Float;
//        }) : async*() {
//
//            let liquidable_positions = borrow_registry.get_liquidable_positions({ time; });
//
//            let to_liquidate = IterUtils.fold_left(liquidable_positions, { borrowed = 0.0; collateral = 0.0; }, func (acc: TotalToLiquidate, position: BorrowPosition): TotalToLiquidate {
//                {
//                    borrowed = acc.borrowed + position.borrowed;
//                    collateral = acc.collateral + position.collateral;
//                };
//            });
//
//            // Ceil the collateral to be sure to sell enough
//            let collateral_to_sell = Int.abs(Float.toInt(Float.ceil(to_liquidate.collateral)));
//
//            await* sell_collateral({ amount = collateral_to_sell; });
//
//            // @todo: the total borrowed shall take the slippage into account because otherwise the
//            // available total liquidity computation will be wrong (i.e. not reflect the amount actually available)
//            //let ratio_sold = Float.fromInt(collateral_sold) / Float.fromInt(collateral_to_sell);
//            
//            // Update the positions
//            for (position in liquidable_positions.reset()) {
//                ignore lending_pool.slash_borrow({ 
//                    account = position.account;
//                    borrow_amount = position.borrowed * ratio_sold;
//                    collateral_amount = position.collateral * ratio_sold;
//                });
//            };
//
//            let value_sold = Float.fromInt(collateral_sold) * collateral_spot_in_asset();
//            let value_debt = to_liquidate.borrowed * ratio_sold;
//
//            let difference = value_sold - value_debt;
//
//            // @todo: need to take protocol fees
//
//            if (difference >= 0.0) {
//                asset_accounting.reserve += difference;
//            } else {
//                Debug.print("⚠️ Bad debt: liquidation proceeds are insufficient");
//                asset_accounting.unsolved_debts := Array.append(asset_accounting.unsolved_debts, [{ timestamp = time; amount = difference; }]);
//            };
//        };

        // @todo: should be available to the protocol only
//        public func solve_debts_with_reserve() {
//
//            let debts_left = Buffer.Buffer<DebtEntry>(0);
//
//            for(debt in Array.vals(asset_accounting.unsolved_debts)){
//                if (debt.amount < asset_accounting.reserve) {
//                    asset_accounting.reserve -= debt.amount;
//                } else {
//                    debts_left.add(debt);
//                };
//            };
//
//            asset_accounting.unsolved_debts := Buffer.toArray(debts_left);
//        };

    

    };

};