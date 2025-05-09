import Result "mo:base/Result";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";

import Map "mo:map/Map";

import InterestRateCurve "../InterestRateCurve";
import Math "../utils/Math";
import Types "../Types";
import Duration "../duration/Duration";
import BorrowRegistry "BorrowRegistry";
import SupplyRegistry "SupplyRegistry";

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
    type BorrowInput = BorrowRegistry.BorrowInput;

    type QueriedBorrowPosition = {
        position: BorrowPosition;
        debt: Float;
        health: Float;
        borrow_time_ratio: Float;
    };

    type LendingPoolState = {
        max_borrow_duration: Duration; // the maximum duration a borrow position can last before it gets liquidated
        max_ltv: Float; // ratio, between 0 and 1, e.g. 0.75
        liquidation_threshold: Float; // ratio, between 0 and 1, e.g. 0.85
        liquidation_penalty: Float; // ratio, between 0 and 1, e.g. 0.10
        reserve_liquidity: Float; // portion of supply reserved (0.0 to 1.0, e.g., 0.1 for 10%), to mitigate illiquidity risk
        protocol_fee: Float; // portion of the supply interest reserved as a fee for the protocol
        var supply_rate: Float; // supply percentage rate (ratio)
        var supply_accrued_interests: Float; // accrued supply interests
        var borrow_index: Float; // growing value, starts at 1.0
        var last_update_timestamp: Nat; // timestamp in nanoseconds
    };

    type CollateralPriceQueries = {
        twap_in_asset: () -> Float;
        spot_in_asset: () -> Float;
    };

    public class LendingPool({
        state: LendingPoolState;
        borrow_registry: BorrowRegistry.BorrowRegistry;
        supply_registry: SupplyRegistry.SupplyRegistry;
        interest_rate_curve: InterestRateCurve.InterestRateCurve;
        collateral_price: CollateralPriceQueries;
    }){

        // Verify state is valid
        if (state.max_ltv > state.liquidation_threshold){
            Debug.trap("Max LTV exceeds liquidation threshold");
        }; 
        if (state.liquidation_penalty != (1.0 - state.liquidation_threshold)){
            // The current liquidation mechanism liquidates all the collateral
            Debug.trap("Liquidation penalty should be equal to {1.0 - liquidation_threshold}");
        };

        public func add_supply(position: SupplyPosition) {
            state.supply_accrued_interests += interests;
            supply_registry.add_supply(position);
        };

        public func slash_supply({ account: Account; amount: Nat; interests: Float; }) : ?SupplyPosition {
            state.supply_accrued_interests -= interests;
            supply_registry.slash_supply({ account; amount; });
        };

        public func get_supply_position({ account: Account; }) : ?SupplyPosition {
            supply_registry.get_position({account});
        };

        public func add_borrow({ input: BorrowInput; current_index: Float; }) : BorrowPosition {
            borrow_registry.add_borrow({ input; current_index });
        };

        public func slash_borrow({ account: Account; borrow_amount: Float; collateral_amount: Float; }) : ?BorrowPosition {
            borrow_registry.slash_borrow({ account; borrow_amount; collateral_amount });
        };

        public func get_borrow_position({ account: Account; }) : ?BorrowPosition {
            borrow_registry.get_position({ account });
        };

        public func get_borrow_positions() : Map.Iter<BorrowPosition> {
            borrow_registry.get_positions();
        };

        public func get_borrow_index() : Float {
            state.borrow_index;
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
        public func accrue_interests_and_update_rates({ 
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

            // Get the current borrow rate from the curve
            let borrow_rate = Math.percentage_to_ratio(interest_rate_curve.get_apr(utilization));
            state.borrow_index *= (1.0 + borrow_rate * elapsed_annual);
            
            // Accrue the supply interests
            state.supply_accrued_interests += Float.fromInt(supply_registry.get_total_supplied()) * state.supply_rate * elapsed_annual;

            // Update the supply rate
            state.supply_rate := borrow_rate * utilization * (1.0 - state.protocol_fee);
            
            // Refresh update timestamp
            state.last_update_timestamp := time;
        };

        public func available_liquidity() : Float {
            Float.fromInt(supply_registry.get_total_supplied()) - borrow_registry.get_total_borrowed();
        };

        public func current_owed({
            position: {
                borrowed: Float;
                borrow_index: Float;
            }
        }) : Float {
            position.borrowed * (state.borrow_index / position.borrow_index);
        };

        public func ltv({
            position: {
                collateral: Float;
                borrowed: Float;
                borrow_index: Float;
            };
        }) : Float {

            (position.collateral * collateral_price.twap_in_asset()) / 
            (current_owed({ position }));
        };

        public func is_valid_ltv({
            position: {
                collateral: Float;
                borrowed: Float;
                borrow_index: Float;
            };
        }) : Bool {

            ltv({ position; }) < state.max_ltv;
        };

        public func health_factor({
            position: {
                collateral: Float;
                borrowed: Float;
                borrow_index: Float;
            };
        }) : Float {
            state.liquidation_threshold / ltv({position});
        };

        public func is_healthy({
            position: {
                collateral: Float;
                borrowed: Float;
                borrow_index: Float;
            };
        }) : Bool {
            
            health_factor({position}) > 1.0;
        };

        public func borrow_time_ratio({
            position: {
                timestamp: Nat;
            };
            time: Nat;
        }) : Float {
            Float.fromInt(time - position.timestamp) / Float.fromInt(Duration.toTime(state.max_borrow_duration));
        };

        public func is_within_borrow_duration({
            position: {
                timestamp: Nat;
            };
            time: Nat;
        }) : Bool {
            borrow_time_ratio({ position; time; }) < 1.0;
        };

        public func current_utilization() : Float {
            
            compute_utilization({ 
                total_supplied = supply_registry.get_total_supplied();
                total_borrowed = borrow_registry.get_total_borrowed();
            });
        };

        public func preview_utilization({
            borrow_to_add: Float;
        }) : Float {
            compute_utilization({ 
                total_supplied = supply_registry.get_total_supplied();
                total_borrowed = borrow_registry.get_total_borrowed() + borrow_to_add;
            });
        };

        public func compute_utilization({
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

        public func get_supply_accrued_interests() : Float {
            state.supply_accrued_interests;
        };

        public func query_borrow_position({ account: Account; time: Nat; }) : ?QueriedBorrowPosition {

            switch (borrow_registry.get_position({ account })){
                case(null) { null; };
                case(?position) {
                    
                    // @todo: will compilation fail if used in a query?
                    accrue_interests_and_update_rates({ time; });

                    ?{
                        position;
                        health = health_factor({ position; });
                        borrow_time_ratio = borrow_time_ratio({ position; time; });
                        debt = current_owed({ position });
                    };
                };
            };
        };
    };

};