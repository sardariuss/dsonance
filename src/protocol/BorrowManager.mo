import Result "mo:base/Result";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Nat "mo:base/Nat";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Buffer "mo:base/Buffer";

import Map "mo:map/Map";

import MapUtils "utils/Map";
import Register "utils/Register";
import LedgerFacade "payement/LedgerFacade";
import InterestRateCurve "InterestRateCurve";
import Math "utils/Math";
import Types "Types";
import Duration "duration/Duration";

module {

    type Account = Types.Account;
    type TxIndex = Types.TxIndex;
    type Register<T> = Types.Register<T>;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type Transfer = Types.Transfer;
    type Duration = Types.Duration;

    type BorrowPosition = {
        timestamp: Nat;
        account: Account;
        var collateral_tx: [TxIndex];
        var borrow_tx: [TxIndex];
        var collateral: Nat;
        var borrowed: Float;
        var borrow_index: Float;
    };

    type SupplyPosition = {
        account: Account;
        var supplied: Nat;
    };

    type WithdrawEntry = {
        account: Account;
        supplied: Nat;
        interest: Nat;
        var state: {
            #PENDING;
            #TRIGGERED;
            #COMPLETED;
        };
    };

    type SBorrowPosition = {
        timestamp: Nat;
        account: Account;
        collateral_tx: [TxIndex];
        borrow_tx: [TxIndex];
        collateral: Nat;
        borrowed: Float;
        borrow_index: Float;
    };

    type QueriedBorrowPosition = {
        position: SBorrowPosition;
        debt: Float;
        health: Float;
        borrow_time_ratio: Float;
    };

    public class BorrowManager({
        borrow_ledger: LedgerFacade.LedgerFacade;
        collateral_ledger: LedgerFacade.LedgerFacade;
        pool: LendingPool;
        borrow_positions: Map.Map<Account, BorrowPosition>;
        supply_positions: Map.Map<Account, SupplyPosition>;
        sell_collateral: (Nat) -> async*(); // @todo: need to take into account slippage
        withdraw_queue: Register<WithdrawEntry>;
    }) {

        public func supply({ account: Account; amount: Nat; time: Nat; }){
            // Need to refresh the indexes before changing the total_supply, otherwise the wrong utilization will be computed on this period?
            pool.accrue_interests_and_update_rates({ time; });

            switch(Map.get(supply_positions, MapUtils.acchash, account)){
                case(null) {
                    Map.set(supply_positions, MapUtils.acchash, account, {
                        account;
                        var supplied = amount;
                    });
                };
                case(?position) {
                    position.supplied += amount;
                };
            };

            pool._state().total_supply += amount;
        };

        /// This function access shall be restricted to the protocol only and called at the end of each lock
        public func withdraw({ account: Account; time: Nat; interest: Nat; }) : Result<(), Text> {

            let position = switch(Map.get(supply_positions, MapUtils.acchash, account)){
                case(null) {
                    return #err("Supply position not found");
                };
                case(?p) { p };
            };

            // Need to refresh the indexes before changing the total_supply, otherwise the wrong utilization will be computed on this period?
            pool.accrue_interests_and_update_rates({ time; });

            if (Float.fromInt(interest) > pool._state().supply_accrued_interests) {
                return #err("Interest exceeds accrued interests");
            };

            // Remove from the accrued interests
            pool._state().supply_accrued_interests -= Float.fromInt(interest);

            ignore Register.add<WithdrawEntry>(withdraw_queue, { account; supplied = position.supplied; interest; var state = #PENDING; });

            Map.delete(supply_positions, MapUtils.acchash, account);
            
            #ok;
        };

        public func borrow({
            account: Account;
            amount: Nat;
            collateral: Nat;
            time: Nat
        }) : async* Result<(), Text> {

            // Refresh the indexes
            pool.accrue_interests_and_update_rates({ time; });

            // Create a copy to not modify the current total for preview
            let pool_copy = pool.copy();
            pool_copy._state().total_borrowed += Float.fromInt(amount);

            // Verify the utilization does not exceed the allowed limit
            let utilization = pool_copy.compute_utilization();
            if (utilization > 1.0) {
                return #err("Utilization of " # debug_show(utilization) # " is greater than 1.0");
            };

            let position = {
                collateral;
                borrowed = Float.fromInt(amount);
                borrow_index = pool_copy._state().borrow_index;
            };

            // Verify the position's LTV
            if (not pool_copy.is_valid_ltv({ position; })) {
                return #err("Loan to value ratio is above current maximum");
            };

            // Transfer the collateral from the user account
            let collateral_tx = switch(await* collateral_ledger.transfer_from({ from = account; amount = collateral; })){
                case(#err(_)) { return #err("Failed to transfer collateral from the user account"); };
                case(#ok(tx)) { tx; };
            };

            // Transfer the borrow amount to the user account
            let borrow_tx = switch((await* borrow_ledger.transfer({ to = account; amount = amount; })).result){
                case(#err(_)) { return #err("Failed to transfer borrow amount to the user account"); };
                case(#ok(tx)) { tx; };
            };

            switch(Map.get(borrow_positions, MapUtils.acchash, account)){
                case(null){
                    Map.set(borrow_positions, MapUtils.acchash, account, {
                        timestamp = time;
                        account;
                        var collateral_tx = [collateral_tx];
                        var borrow_tx = [borrow_tx];
                        var collateral = collateral;
                        var borrowed = Float.fromInt(amount);
                        var borrow_index = pool._state().borrow_index;
                    });
                };
                case(?position){
                    // Update the position
                    position.collateral_tx := Array.append(position.collateral_tx, [collateral_tx]);
                    position.borrow_tx := Array.append(position.borrow_tx, [borrow_tx]);
                    position.collateral += collateral;
                    position.borrowed := pool.current_owed({ position = share_position(position); }) + Float.fromInt(amount);
                    position.borrow_index := pool._state().borrow_index;
                };
            };

            pool._state().total_borrowed += Float.fromInt(amount);
            pool._state().total_collateral += collateral;

            #ok;
        };

        public func repay({ 
            account: Account;
            amount: Nat;
            time: Nat;
        }) : async* Result<(), Text> {

            let position = switch (Map.get<Account, BorrowPosition>(borrow_positions, MapUtils.acchash, account)) {
                case (null) { return #err("Position not found"); };
                case (?p) { p; };
            };

            // Refresh the indexes
            pool.accrue_interests_and_update_rates({ time; });

            let owed = pool.current_owed({ position = share_position(position); });
            let repaid_amount = Float.min(owed, Float.fromInt(amount));

            // Transfer the repayment from the user to the contract/pool
            switch(await* borrow_ledger.transfer_from({ from = account; amount = Int.abs(Float.toInt(Float.ceil(repaid_amount))); })){
                case(#err(_)) { return #err("Transfer failed"); };
                case(#ok(_)) {};
            };
            let repaid_fraction = repaid_amount / owed;
            let delta = repaid_fraction * position.borrowed;
            position.borrowed -= delta;
            pool._state().total_borrowed -= delta;

            // Reimburse collateral if the position is fully repaid
            if (position.borrowed <= 0.0){
                return await* reimburse_collateral({account});
            };

            #ok;
        };

        public func reimburse_collateral({
            account: Account;
        }) : async* Result<(), Text> {

            let position = switch (Map.get<Account, BorrowPosition>(borrow_positions, MapUtils.acchash, account)) {
                case (null) { return #err("Position not found"); };
                case (?p) { p; };
            };

            if (position.borrowed > 0.0){
                return #err("The borrow position is not fully repaid yet");
            };
                
            // Transfer back the collateral
            switch((await* collateral_ledger.transfer({ to = account; amount = position.collateral; })).result){
                case(#err(_)) { 
                    return #err("Collateral reimbursement failed");
                };
                case(#ok(_)) {};
            };

            pool._state().total_collateral -= position.collateral;
            Map.delete(borrow_positions, MapUtils.acchash, account);

            #ok;
        };

        /// Liquidate borrow positions if their health factor is below 1.0.
        /// @todo: this function access shall be restricted to the protocol only and called by a timer
        public func check_all_positions_and_liquidate({ time: Nat; }) : async*() {

            pool.accrue_interests_and_update_rates({ time; });

            let to_liquidate = Buffer.Buffer<BorrowPosition>(0);
            var sum_borrowed = 0.0;
            var sum_collateral = 0;

            label liquidation_loop for (p in Map.vals(borrow_positions)){

                if (p.borrowed <= 0.0) {
                    Debug.print("The borrow position has already been repaid");
                    continue liquidation_loop;
                };

                let position = share_position(p);

                let is_healthy = pool.is_healthy({ position; });
                let is_within_borrow_duration = pool.is_within_borrow_duration({ position; time; });
                
                // Liquidate if not healthy or not within the borrow duration
                if (not is_healthy or not is_within_borrow_duration){
                    to_liquidate.add(p);
                    sum_borrowed += p.borrowed;
                    sum_collateral += p.collateral;
                };
            };

            await* sell_collateral(sum_collateral);

            pool._state().total_borrowed -= sum_borrowed;
            pool._state().total_collateral -= sum_collateral;
            
            // Finally delete the positions
            for (position in to_liquidate.vals()) {
                Map.delete(borrow_positions, MapUtils.acchash, position.account);
            };
        };

        /// This function access shall be restricted to the protocol only and called by a timer
        public func process_withdraw_queue() : async* Result<(), Text> {

            let transfers = Map.new<Nat, async* (Transfer)>();

            label process_queue for ((id, entry) in Register.entries(withdraw_queue)){

                // Ignore entries which had already been processed
                if (entry.state != #PENDING){
                    continue process_queue;
                };

                let entry_due = entry.supplied + entry.interest;

                // Not enough liquidity to process the withdrawal
                if (pool.available_liquidity() < Float.fromInt(entry_due)) {
                    Debug.print("Not enough liquidity to process the withdrawal");
                    break process_queue;
                };

                entry.state := #TRIGGERED;
                Map.set(transfers, Map.nhash, id, collateral_ledger.transfer({ to = entry.account; amount = entry_due; }));
                pool._state().total_supply -= entry.supplied;
            };

            var result : Result<(), Text> = #ok;

            for ((id, transfer) in Map.entries(transfers)){
                switch((await* transfer).result){
                    case(#ok(_)){
                        
                        // Tag the withdrawal as completed
                        switch(Register.find(withdraw_queue, id)){
                            case(null) {}; // Should never happen
                            case(?entry){
                                entry.state := #COMPLETED;
                            };
                        };
                    };
                    case(#err(_)){

                        result := #err("At least one withdrawal transfer failed");
                        
                        // Revert the withdrawal to be processed later
                        switch(Register.find(withdraw_queue, id)){
                            case(null) {}; // Should never happen
                            case(?entry){
                                entry.state := #PENDING;
                                pool._state().total_supply += entry.supplied;
                            };
                        };
                    };
                };
            };

            result;
        };

        public func get_borrow_position({ account: Account; time: Nat; }) : ?QueriedBorrowPosition {

            switch (Map.get(borrow_positions, MapUtils.acchash, account)){
                case(null) { null; };
                case(?p) {
                    // Create a copy to avoid modifing current state (query requirement)
                    let pool_copy = pool.copy();
                    pool_copy.accrue_interests_and_update_rates({ time; });

                    let position = share_position(p);

                    ?{
                        position;
                        health = pool_copy.health_factor({ position; });
                        borrow_time_ratio = pool_copy.borrow_time_ratio({ position; time; });
                        debt = pool_copy.current_owed({ position });
                    };
                };
            };
        };

    };

    type LendingPoolState = {
        max_borrow_duration: Duration; // the maximum duration a borrow position can last before it gets liquidated
        max_ltv: Float; // ratio, between 0 and 1, e.g. 0.75
        liquidation_threshold: Float; // ratio, between 0 and 1, e.g. 0.85
        liquidation_penalty: Float; // ratio, between 0 and 1, e.g. 0.10
        reserve_liquidity: Float; // portion of supply reserved (0.0 to 1.0, e.g., 0.1 for 10%), to mitigate illiquidity risk
        protocol_fee: Float; // portion of the supply interest reserved as a fee for the protocol
        var total_supply: Nat; // total supply
        var supply_rate: Float; // supply percentage rate (ratio)
        var supply_accrued_interests: Float; // accrued supply interests
        var total_collateral: Nat; // total collateral
        var total_borrowed: Float; // total borrowed
        var borrow_index: Float; // growing value, starts at 1.0
        var last_update_timestamp: Nat; // timestamp in nanoseconds
    };

    type TwapQueries = {
        get_collateral_twap_usd: () -> Float;
        get_supply_twap_usd: () -> Float;
    };

    public class LendingPool({
        state: LendingPoolState;
        interest_rate_curve: InterestRateCurve.InterestRateCurve;
        twap_queries: TwapQueries;
    }){

        // Verify state is valid
        if (state.max_ltv > state.liquidation_threshold){
            Debug.trap("Max LTV exceeds liquidation threshold");
        }; 
        if (state.liquidation_penalty != (1.0 - state.liquidation_threshold)){
            // The current liquidation mechanism liquidates all the collateral
            Debug.trap("Liquidation penalty should be equal to {1.0 - liquidation_threshold}");
        };

        public func _state() : LendingPoolState {
            state;
        };

        public func copy() : LendingPool {
            LendingPool({
                state = {
                    max_borrow_duration          = state.max_borrow_duration;
                    max_ltv                      = state.max_ltv;
                    liquidation_threshold        = state.liquidation_threshold;
                    liquidation_penalty          = state.liquidation_penalty; 
                    reserve_liquidity            = state.reserve_liquidity;
                    protocol_fee                 = state.protocol_fee;
                    var total_supply             = state.total_supply;
                    var total_collateral         = state.total_collateral;
                    var total_borrowed           = state.total_borrowed;
                    var borrow_index             = state.borrow_index;
                    var supply_rate              = state.supply_rate;
                    var last_update_timestamp    = state.last_update_timestamp;
                    var supply_accrued_interests = state.supply_accrued_interests;
                };
                interest_rate_curve;
                twap_queries;
            });
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
            let utilization = compute_utilization();

            // Get the current borrow rate from the curve
            let borrow_rate = Math.percentageToRatio(interest_rate_curve.get_apr(utilization));
            state.borrow_index *= (1.0 + borrow_rate * elapsed_annual);
            
            // Accrue the supply interests
            state.supply_accrued_interests += Float.fromInt(state.total_supply) * state.supply_rate * elapsed_annual;

            // Update the supply rate
            state.supply_rate := borrow_rate * utilization * (1.0 - state.protocol_fee);
            
            // Refresh update timestamp
            state.last_update_timestamp := time;
        };

        public func available_liquidity() : Float {
            Float.fromInt(state.total_supply) - state.total_borrowed;
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
                collateral: Nat;
                borrowed: Float;
                borrow_index: Float;
            };
        }) : Float {

            let collateral_twap_usd = twap_queries.get_collateral_twap_usd();
            let supply_twap_usd = twap_queries.get_supply_twap_usd();

            (Float.fromInt(position.collateral) * collateral_twap_usd) / 
            (current_owed({ position }) * supply_twap_usd);
        };

        public func is_valid_ltv({
            position: {
                collateral: Nat;
                borrowed: Float;
                borrow_index: Float;
            };
        }) : Bool {

            ltv({ position; }) < state.max_ltv;
        };

        public func health_factor({
            position: {
                collateral: Nat;
                borrowed: Float;
                borrow_index: Float;
            };
        }) : Float {
            state.liquidation_threshold / ltv({position});
        };

        public func is_healthy({
            position: {
                collateral: Nat;
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

        public func compute_utilization() : Float {
            
            if (state.total_supply == 0) {
                if (state.total_borrowed > 0) {
                    // Treat utilization as 100% to maximize borrow rate
                    return 1.0;
                };
                // No supply nor borrowed, consider that the utilization is null
                return 0.0;
            };
            
            (state.total_borrowed * state.borrow_index) / (Float.fromInt(state.total_supply) * (1.0 - state.reserve_liquidity));
        };
    };

    func share_position(position: BorrowPosition) : SBorrowPosition {
        {
            timestamp     = position.timestamp;
            account       = position.account;
            collateral_tx = position.collateral_tx;
            borrow_tx     = position.borrow_tx;
            collateral    = position.collateral;
            borrowed      = position.borrowed;
            borrow_index  = position.borrow_index;
        };
    };

};