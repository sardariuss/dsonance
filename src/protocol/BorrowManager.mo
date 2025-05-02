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
        amount_due: Nat;
        var state: {
            #PENDING;
            #TRIGGERED;
            #COMPLETED;
        };
    };

    type SBorrowPosition = {
        account: Account;
        collateral_tx: [TxIndex];
        borrow_tx: [TxIndex];
        collateral: Nat;
        borrowed: Float;
        borrow_index: Float;
    };

    type LendingPoolState = {
        max_borrow_duration: Duration;
        liquidity_threshold: Float; // e.g. 0.85 means 85%
        // @todo: rename reserve_ratio into reserve_liquidity ?
        reserve_ratio: Float; // portion of supply reserved (0.0 to 1.0, e.g., 0.1 for 10%), to mitigate illiquidity risk
        reserve_fee: Float; // portion of the supply interest reserved as a fee for the protocol
        var total_supply: Nat; // total supply
        var total_collateral: Nat; // total collateral
        var total_borrowed: Float; // total borrowed
        var borrow_index: Float; // growing value, starts at 1.0
        var supply_index: Float; // growing value, starts at 1.0
        var last_update_timestamp: Nat; // Timestamp in nanoseconds
    };

    type SLendingPoolState = {
        max_borrow_duration: Duration;
        liquidity_threshold: Float;
        reserve_ratio: Float;
        reserve_fee: Float;
        total_supply: Nat;
        total_collateral: Nat;
        total_borrowed: Float;
        borrow_index: Float;
        supply_index: Float;
        last_update_timestamp: Nat;
    };

    public class BorrowManager({
        borrow_ledger: LedgerFacade.LedgerFacade;
        collateral_ledger: LedgerFacade.LedgerFacade;
        pool: LendingPoolState;
        interest_rate_curve: InterestRateCurve.InterestRateCurve;
        borrow_positions: Map.Map<Account, BorrowPosition>;
        supply_positions: Map.Map<Account, SupplyPosition>;
        sell_collateral: (Nat) -> async*();
        get_collateral_twap_usd: () -> Float;
        get_supply_twap_usd: () -> Float;
        withdraw_queue: Register<WithdrawEntry>;
    }) {

        public func supply({ account: Account; amount: Nat; time: Nat; }){
            // Need to refresh the indexes before changing the total_supply, otherwise the wrong utilization will be computed on this period?
            refresh_indexes({time});

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

            pool.total_supply += amount;
        };

        /// This function access shall be restricted to the protocol only and called at the end of each lock
        public func withdraw({ account: Account; time: Nat; amount_due: Nat; }) : Result<(), Text> {

            let position = switch(Map.get(supply_positions, MapUtils.acchash, account)){
                case(null) {
                    return #err("Supply position not found");
                };
                case(?p) { p };
            };

            // Need to refresh the indexes before changing the total_supply, otherwise the wrong utilization will be computed on this period?
            refresh_indexes({time});

            ignore Register.add<WithdrawEntry>(withdraw_queue, { account; supplied = position.supplied; amount_due; var state = #PENDING; });

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
            refresh_indexes({time});

            let utilization = compute_utilization({
                share_lending_pool(pool) with
                total_borrowed = pool.total_borrowed + Float.fromInt(amount)
            });

            if (utilization > 1.0) {
                return #err("Utilization exceeds allowed limit");
            };

            let position = {
                collateral;
                borrowed = Float.fromInt(amount);
                borrow_index = pool.borrow_index;
            };

            if (health_factor(position) < 1.0) {
                return #err("Borrowing would result in under-collateralized position.");
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
                        var borrow_index = pool.borrow_index;
                    });
                };
                case(?position){
                    // Update the position
                    position.collateral_tx := Array.append(position.collateral_tx, [collateral_tx]);
                    position.borrow_tx := Array.append(position.borrow_tx, [borrow_tx]);
                    position.collateral += collateral;
                    position.borrowed := current_owed(share_position(position)) + Float.fromInt(amount);
                    position.borrow_index := pool.borrow_index;
                };
            };

            pool.total_borrowed += Float.fromInt(amount);
            pool.total_collateral += collateral;

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
            refresh_indexes({time});

            let owed = current_owed(share_position(position));
            let repaid_amount = Float.min(owed, Float.fromInt(amount));

            // Transfer the repayment from the user to the contract/pool
            switch(await* borrow_ledger.transfer_from({ from = account; amount = Int.abs(Float.toInt(Float.ceil(repaid_amount))); })){
                case(#err(_)) { return #err("Transfer failed"); };
                case(#ok(_)) {};
            };
            let repaid_fraction = repaid_amount / owed;
            let delta = repaid_fraction * position.borrowed;
            position.borrowed -= delta;
            pool.total_borrowed -= delta;

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

            pool.total_collateral -= position.collateral;
            Map.delete(borrow_positions, MapUtils.acchash, account);

            #ok;
        };

        /// Liquidate borrow positions if their health factor is below 1.0.
        /// This function access shall be restricted to the protocol only and called by a timer
        public func check_all_positions_and_liquidate({ time: Nat; }) : async*() {

            refresh_indexes({time});

            let to_liquidate = Buffer.Buffer<BorrowPosition>(0);
            var sum_borrowed = 0.0;
            var sum_collateral = 0;

            label liquidation_loop for (position in Map.vals(borrow_positions)){

                if (position.borrowed <= 0.0) {
                    Debug.print("The borrow position has already been repaid");
                    continue liquidation_loop;
                };

                let unhealthy = health_factor(share_position(position)) <= 1.0;
                let age : Int = (time - position.timestamp);
                let too_old = age > Duration.toTime(pool.max_borrow_duration);
                
                // Determine position's health factor
                if (unhealthy or too_old){
                    to_liquidate.add(position);
                    sum_borrowed += position.borrowed;
                    sum_collateral += position.collateral;
                };
            };

            await* sell_collateral(sum_collateral);

            pool.total_borrowed -= sum_borrowed;
            pool.total_collateral -= sum_collateral;
            
            // Finally delete the positions
            for (position in to_liquidate.vals()) {
                Map.delete(borrow_positions, MapUtils.acchash, position.account);
            };
        };

        func available_liquidity() : Float {
            Float.fromInt(pool.total_supply) - pool.total_borrowed;
        };

        type BeingWithdrawn = {
            entry: WithdrawEntry;
            transfer_call: async* (Transfer);
        };

        /// This function access shall be restricted to the protocol only and called by a timer
        func process_withdraw_queue() : async* Result<(), Text> {

            let transfers = Map.new<Nat, async* (Transfer)>();

            label process_queue for ((id, entry) in Register.entries(withdraw_queue)){

                // Ignore entries which had already been processed
                if (entry.state != #PENDING){
                    continue process_queue;
                };

                // Not enough liquidity to process the withdrawal
                if (available_liquidity() < Float.fromInt(entry.amount_due)) {
                    Debug.print("Not enough liquidity to process the withdrawal");
                    break process_queue;
                };

                entry.state := #TRIGGERED;
                Map.set(transfers, Map.nhash, id, collateral_ledger.transfer({ to = entry.account; amount = entry.amount_due; }));
                pool.total_supply -= entry.supplied;
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
                                pool.total_supply += entry.supplied;
                            };
                        };
                    };
                };
            };

            result;
        };

        func refresh_indexes({ time: Nat; }) {

            let elapsed_ns : Int = time - pool.last_update_timestamp;

            // If the time is before the last update
            if (elapsed_ns < 0) {
                Debug.trap("Cannot update rate: time is before last update");
            } else if (elapsed_ns == 0) {
                Debug.print("Rate is already up to date");
                return;
            };

            // Calculate the time period in years
            let elapsed_annual = Duration.toAnnual(Duration.getDuration({ from = pool.last_update_timestamp; to = time; }));

            // Calculate utilization ratio
            let utilization = compute_utilization(share_lending_pool(pool));

            // Get the current borrow rate from the curve
            let borrow_rate = Math.percentageToRatio(interest_rate_curve.get_apr(utilization));
            pool.borrow_index *= (1.0 + borrow_rate * elapsed_annual);

            // Get the current supply rate
            let supply_rate = borrow_rate * utilization * (1.0 - pool.reserve_fee);
            pool.supply_index *= (1.0 + supply_rate * elapsed_annual);

            pool.last_update_timestamp := time;
        };

        func current_owed({
            borrowed: Float;
            borrow_index: Float;
        }) : Float {
            borrowed * (pool.borrow_index / borrow_index);
        };

        func health_factor({
            collateral: Nat;
            borrowed: Float;
            borrow_index: Float;
        }) : Float {
            (Float.fromInt(collateral) * get_collateral_twap_usd() * pool.liquidity_threshold) / 
            (current_owed({borrowed; borrow_index;}) * get_supply_twap_usd());
        };

    };

    func compute_utilization({
        total_supply: Nat;
        total_borrowed: Float;
        borrow_index: Float;
        reserve_ratio: Float;
    }) : Float {
         
        if (total_supply == 0) {
            if (total_borrowed > 0) {
                // Treat utilization as 100% to maximize borrow rate
                return 1.0;
            };
            // No supply nor borrowed, consider that the utilization is null
            return 0.0;
        };
        
        (total_borrowed * borrow_index) / (Float.fromInt(total_supply) * (1.0 - reserve_ratio));
    };

    func share_position(position: BorrowPosition) : SBorrowPosition {
        {
            account       = position.account;
            collateral_tx = position.collateral_tx;
            borrow_tx     = position.borrow_tx;
            collateral    = position.collateral;
            borrowed      = position.borrowed;
            borrow_index  = position.borrow_index;
        };
    };

    func share_lending_pool(pool: LendingPoolState) : SLendingPoolState {
        {
            max_borrow_duration   = pool.max_borrow_duration;
            liquidity_threshold   = pool.liquidity_threshold;
            reserve_ratio         = pool.reserve_ratio;
            reserve_fee           = pool.reserve_fee;
            total_supply          = pool.total_supply;
            total_collateral      = pool.total_collateral;
            total_borrowed        = pool.total_borrowed;
            borrow_index          = pool.borrow_index;
            supply_index          = pool.supply_index;
            last_update_timestamp = pool.last_update_timestamp;
        }
    };

};