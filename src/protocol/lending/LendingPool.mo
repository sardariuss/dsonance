import Result "mo:base/Result";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";

import Map "mo:map/Map";

import InterestRateCurve "../InterestRateCurve";
import Math "../utils/Math";
import Types "../Types";
import Duration "../duration/Duration";
import BorrowRegistry "BorrowRegistry";
import SupplyRegistry "SupplyRegistry";
import IterUtils "../utils/Iter";
import Index "Index";

module {

    type Account = Types.Account;
    type TxIndex = Types.TxIndex;
    type Register<T> = Types.Register<T>;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type Transfer = Types.Transfer;
    type Duration = Types.Duration;

    type SupplyPosition = SupplyRegistry.SupplyPosition;
    type SupplyInput = SupplyRegistry.SupplyInput;
    type BorrowPosition = BorrowRegistry.BorrowPosition;
    type RepaymentArgs = BorrowRegistry.RepaymentArgs;

    type LendingPoolState = {
        liquidation_penalty: Float; // ratio, between 0 and 1, e.g. 0.10
        reserve_liquidity: Float; // portion of supply reserved (0.0 to 1.0, e.g., 0.1 for 10%), to mitigate illiquidity risk
        protocol_fee: Float; // portion of the supply interest reserved as a fee for the protocol
        var supply_rate: Float; // supply percentage rate (ratio)
        var supply_accrued_interests: Float; // accrued supply interests
        var borrow_index: Float; // growing value, starts at 1.0
        var supply_index: Float; // growing value, starts at 1.0
        var last_update_timestamp: Nat; // last time the rates were updated
    };

//    type SellCollateralQuery = ({
//        amount: Nat;
//        max_slippage: Float;
//    }) -> async* Result<{ sold_amount: Nat }, Text>;

    // @todo: Take care of the slippage
    type SellCollateralQuery = ({
        amount: Nat;
    }) -> async* ();

    type DebtEntry = { 
        timestamp: Nat;
        amount: Float;
    };

    type AssetAccounting = {
        var reserve: Float; // amount of asset reserved for unsolved debts
        var unsolved_debts: [DebtEntry]; // debts that are not solved yet
    };

    public class LendingPool({
        state: LendingPoolState;
        borrow_registry: BorrowRegistry.BorrowRegistry;
        supply_registry: SupplyRegistry.SupplyRegistry;
        interest_rate_curve: InterestRateCurve.InterestRateCurve;
        sell_collateral: SellCollateralQuery;
        asset_accounting: AssetAccounting;
        max_slippage: Float;
    }){

        public func get_supplied({ id: Text; }) : ?SupplyPosition {
            supply_registry.get_position({ id });
        };

        public func supply({ input: SupplyInput; time: Nat; }) : async* Result<(), Text> {

            accrue_interests_and_update_rates({time}); // Required to accrue interests before the supply changed (@todo: use obs instead)
            
            await* supply_registry.add_position(input);
        };

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

        public func supply_collateral({ 
            account: Account;
            amount: Nat;
        }) : async* Result<(), Text> {
            await* borrow_registry.supply_collateral({ account; amount; });
        };

        public func withdraw_collateral({ 
            account: Account;
            amount: Nat;
            time: Nat;
        }) : async* Result<(), Text> {
            await* borrow_registry.withdraw_collateral({ account; amount; index = get_borrow_index({ time }); });
        };

        public func borrow({ 
            account: Account;
            amount: Nat;
            time: Nat;
        }) : async* Result<(), Text> {

            // @todo: should add to a map of <Account, Nat> the amount borrowed to prevent
            // borrowing more than utilization allows (or liquidity?)

            // Verify the utilization does not exceed the allowed limit
            let utilization = preview_utilization({ borrow_to_add = Float.fromInt(amount); });
            if (utilization > 1.0) {
                return #err("Utilization of " # debug_show(utilization) # " is greater than 1.0");
            };

            await* borrow_registry.borrow({ account; amount; index = get_borrow_index({ time }); });
        };

        public func repay_borrow({
            account: Account;
            args: RepaymentArgs;
            time: Nat;
        }) : async* Result<(), Text> {
            await* borrow_registry.repay({ account; args; index = get_borrow_index({ time }); });
        };

        public func get_borrow_position({ account: Account; }) : ?BorrowPosition {
            borrow_registry.get_position({ account });
        };

        public func get_borrow_positions() : Map.Iter<BorrowPosition> {
            borrow_registry.get_positions();
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
        public func solve_debts_with_reserve() {

            let debts_left = Buffer.Buffer<DebtEntry>(0);

            for(debt in Array.vals(asset_accounting.unsolved_debts)){
                if (debt.amount < asset_accounting.reserve) {
                    asset_accounting.reserve -= debt.amount;
                } else {
                    debts_left.add(debt);
                };
            };

            asset_accounting.unsolved_debts := Buffer.toArray(debts_left);
        };

        /// Accrues interest for the past period and updates supply/borrow rates.
        ///
        /// This function should be called at the boundary between two periods, with `time`
        /// being the current timestamp. It finalizes interest accrued over the period
        /// [last_update_timestamp, time] using the supply and borrow rates from the beginning
        /// of that interval.
        ///
        /// Assumptions:
        /// - Supply interest for a given period is always calculated using the rate at the *start* of the period.
        /// - `supply_rate` and `last_update_timestamp` are updated together and should never be stale relative to one another.
        ///
        /// This model ensures consistency and avoids forward-looking rate assumptions.
        func accrue_interests_and_update_rates({ 
            time: Nat;
        }) {

            let elapsed_ns : Int = time - state.last_update_timestamp;

            // If the time is before the last update
            if (elapsed_ns < 0) {
                Debug.trap("Cannot update rates: time is before last update");
            } else if (elapsed_ns == 0) {
                Debug.print("Rates are already up to date");
                return;
            };

            // Calculate the time period in years
            let elapsed_annual = Duration.toAnnual(Duration.getDuration({ from = state.last_update_timestamp; to = time; }));

            // Calculate utilization ratio
            let utilization = current_utilization();

            // Get the current rates from the curve
            let borrow_rate = Math.percentage_to_ratio(interest_rate_curve.get_apr(utilization));
            state.supply_rate := borrow_rate * utilization * (1.0 - state.protocol_fee);

            // Update the indexes
            state.borrow_index := state.borrow_index * (1.0 + borrow_rate * elapsed_annual);
            state.supply_index := state.supply_index * (1.0 + state.supply_rate * elapsed_annual);
            
            // Accrue the supply interests
            state.supply_accrued_interests += Float.fromInt(supply_registry.get_total_supplied()) * state.supply_rate * elapsed_annual;
            
            // Refresh update timestamp
            state.last_update_timestamp := time;
        };

        func get_borrow_index({ time: Nat; }) : Index.Index {
            accrue_interests_and_update_rates({ time });
            {
                value = state.borrow_index;
                timestamp = time;
            };
        };

        func get_available_interests({ time: Nat; }) : Float {
            accrue_interests_and_update_rates({ time; });
            state.supply_accrued_interests - Array.foldLeft<DebtEntry, Float>(asset_accounting.unsolved_debts, 0.0, func (acc: Float, debt: DebtEntry) {
                acc + debt.amount;
            });
        };

        // @todo: should use the total with accrued interests!
        func get_available_liquidity() : Float {
            Float.fromInt(supply_registry.get_total_supplied()) - borrow_registry.get_total_borrowed();
        };

        func get_virtual_available(): Float {
            Float.fromInt(supply_registry.get_total_supplied()) * state.supply_index - borrow_registry.get_total_borrowed() * state.borrow_index;
        };

        func current_utilization() : Float {
            compute_utilization({ 
                total_supplied = supply_registry.get_total_supplied();
                total_borrowed = borrow_registry.get_total_borrowed();
            });
        };

        func preview_utilization({
            borrow_to_add: Float;
        }) : Float {
            compute_utilization({ 
                total_supplied = supply_registry.get_total_supplied();
                total_borrowed = borrow_registry.get_total_borrowed() + borrow_to_add;
            });
        };

        func compute_utilization({
            total_supplied: Nat;
            total_borrowed: Float;
        }) : Float {
            
            if (total_supplied == 0) {
                if (total_borrowed > 0) {
                    // Treat utilization as 100% to maximize borrow rate
                    return 1.0;
                };
                // No supply nor borrowed, consider that the utilization is null
                return 0.0;
            };
            
            (total_borrowed * state.borrow_index) / (Float.fromInt(total_supplied) * (1.0 - state.reserve_liquidity));
        };

    };

};