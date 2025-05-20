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

        public func withdraw_supply({ id: Text; interest_share: Float; time: Nat; }) : Result<(), Text> {

            if (not Math.is_normalized(interest_share)) {
                return #err("Invalid interest share");
            };

            let position = switch(supply_registry.get_position({ id })){
                case(null) { return #err("Position with id " # debug_show(id) # " not found")};
                case(?p) { p; };
            };

            let interest_amount = interest_share * get_available_interests( { time; });

            // Make sure the total due is positif (if ever the interest are negative and greater in value than the amount supplied)
            let due = Float.max(0, Float.fromInt(position.supplied) + interest_amount);

            // Remove from interests right away, once withdrawal is triggered the protocol makes it so the position 
            // stops to accumulate interests, even if stuck in the withdrawal queue! It is a design choice.
            state.supply_accrued_interests -= due;
            
            supply_registry.remove_position({ id; due = Int.abs(Float.toInt(due)); }); // @todo: use obs to call update_index on total_supplied changed!
        };

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

        public func take_interest_share({ time: Nat; interest_share: Float; position_amount: Nat; }) : Float {
            accrue_interests_and_update_rates({ time; });
            // If the interest share is negative, we want to make sure we don't take more than the amount supplied
            let interests_amount = Float.max(-Float.fromInt(position_amount), state.supply_accrued_interests * interest_share);
            state.supply_accrued_interests -= interests_amount;
            interests_amount;
        };

        public func get_available_interests({ time: Nat; }) : Float {
            accrue_interests_and_update_rates({ time; });
            state.supply_accrued_interests;
            // @todo: uncomment when using unsolved debts
            //state.supply_accrued_interests - Array.foldLeft<DebtEntry, Float>(asset_accounting.unsolved_debts, 0.0, func (acc: Float, debt: DebtEntry) {
                //acc + debt.amount;
            //});
        };

        public func get_virtual_available({ time: Nat }): Float {
            accrue_interests_and_update_rates({ time; });
            Float.fromInt(supply_registry.get_total_supplied()) * state.supply_index - borrow_registry.get_total_borrowed() * state.borrow_index;
        };

    };

};