import Result "mo:base/Result";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Nat "mo:base/Nat";
import Array "mo:base/Array";
import Debug "mo:base/Debug";

import Map "mo:map/Map";

import MapUtils "utils/Map";
import LedgerFacade "payement/LedgerFacade";
import InterestRateCurve "InterestRateCurve";
import Math "utils/Math";
import Types "Types";
import Duration "duration/Duration";

module {

    type Account = Types.Account;
    type TxIndex = Types.TxIndex;
    type Result<Ok, Err> = Result.Result<Ok, Err>;

    type BorrowPosition = {
        account: Account;
        var collateral_tx: [TxIndex];
        var borrow_tx: [TxIndex];
        var collateral: Nat;
        var borrowed: Float;
        var borrow_index: Float;
    };

    type LendingPoolState = {
        liquidity_threshold: Float; // e.g. 0.85 means 85%
        reserve_ratio: Float; // portion of supply reserved (0.0 to 1.0, e.g., 0.1 for 10%), to mitigate illiquidity risk
        reserve_fee: Float; // portion of the supply interest reserved as a fee for the protocol
        var total_supply: Nat; // total supply
        var total_collateral: Nat; // total collateral
        var total_borrowed: Float; // total borrowed
        var borrow_index: Float; // growing value, starts at 1.0
        var supply_index: Float; // growing value, starts at 1.0
        var last_update_timestamp: Nat; // Timestamp in nanoseconds
    };

    public class BorrowManager({
        borrow_ledger: LedgerFacade.LedgerFacade;
        collateral_ledger: LedgerFacade.LedgerFacade;
        pool: LendingPoolState;
        interest_rate_curve: InterestRateCurve.InterestRateCurve;
        borrow_positions: Map.Map<Account, BorrowPosition>;
    }) {

        public func add_supply({ amount: Nat; time: Nat; }){
            // Need to refresh the indexes before changing the total_supply, otherwise the wrong utilization will be computed on this period?
            refresh_indexes({time});
            pool.total_supply += amount;
        };

        public func remove_supply({ amount: Nat; time: Nat; }){
            if (amount > pool.total_supply) {
                Debug.trap("The total supply is smaller than the amount requested to remove");
            };

            // Need to refresh the indexes before changing the total_supply, otherwise the wrong utilization will be computed on this period?
            refresh_indexes({time});

            // @todo: need to liquidate borrow positions if utilization gets greater than 0.0?
            pool.total_supply -= amount;
        };

        public func borrow({
            account: Account;
            borrow_amount: Nat;
            collateral_amount: Nat;
            time: Nat
        }) : async* Result<(), Text> {

            // @todo: need to verify if the borrow_amount will not make utilization greater than 1.0

            // Transfer the collateral from the user account
            let collateral_tx = switch(await* collateral_ledger.transfer_from({ from = account; amount = collateral_amount; })){
                case(#err(_)) { return #err("Failed to transfer collateral from the user account"); };
                case(#ok(tx)) { tx; };
            };

            // Transfer the borrow amount to the user account
            let borrow_tx = switch((await* borrow_ledger.transfer({ to = account; amount = borrow_amount; })).result){
                case(#err(_)) { return #err("Failed to transfer borrow amount to the user account"); };
                case(#ok(tx)) { tx; };
            };

            // Refresh the indexes
            refresh_indexes({time});

            switch(Map.get(borrow_positions, MapUtils.acchash, account)){
                case(null){
                    Map.set(borrow_positions, MapUtils.acchash, account, {
                        account;
                        var collateral_tx = [collateral_tx];
                        var borrow_tx = [borrow_tx];
                        var collateral = collateral_amount;
                        var borrowed = Float.fromInt(borrow_amount);
                        var borrow_index = pool.borrow_index;
                    });
                };
                case(?position){
                    // Update the position
                    position.collateral_tx := Array.append(position.collateral_tx, [collateral_tx]);
                    position.borrow_tx := Array.append(position.borrow_tx, [borrow_tx]);
                    position.collateral += collateral_amount;
                    position.borrowed := current_owed(position) + Float.fromInt(borrow_amount);
                    position.borrow_index := pool.borrow_index;
                };
            };

            pool.total_borrowed += Float.fromInt(borrow_amount);
            pool.total_collateral += collateral_amount;

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

            let owed = current_owed(position);
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

        /// Liquidate a borrow position if its health factor is below 1.0.
        public func liquidate({ borrower: Account;  time: Nat; }) : async* Result<(), Text> {

            let position = switch (Map.get<Account, BorrowPosition>(borrow_positions, MapUtils.acchash, borrower)) {
                case (null) { return #err("No borrow position found for borrower"); };
                case (?p) { p; };
            };

            refresh_indexes({time});

            if (position.borrowed <= 0.0) {
                return #err("The borrow position has already been repaid");
            };
            
            // Determine position's health factor
            if (health_factor(position) >= 1.0) {
                return #err("Position is still healthy");
            };

            // @todo: Sell collateral

            Map.delete(borrow_positions, MapUtils.acchash, borrower);
            pool.total_borrowed -= position.borrowed;
            pool.total_collateral -= position.collateral;

            #ok;
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
            let utilization = do {
                if (pool.total_supply == 0) {
                    // If total supply is 0, utilization is technically undefined or 0.
                    0.0;
                } else {
                    (pool.total_borrowed * pool.borrow_index) / (Float.fromInt(pool.total_supply) * (1.0 - pool.reserve_ratio));
                };
            };

            // Get the current borrow rate from the curve
            let borrow_rate = Math.percentageToRatio(interest_rate_curve.get_apr(utilization));
            pool.borrow_index *= (1.0 + borrow_rate * elapsed_annual);

            // Get the current supply rate
            let supply_rate = borrow_rate * utilization * (1.0 - pool.reserve_fee);
            pool.supply_index *= (1.0 + supply_rate * elapsed_annual);

            pool.last_update_timestamp := time;
        };

        func current_owed(position: BorrowPosition) : Float {
            position.borrowed * (1.0 - pool.borrow_index / position.borrow_index);
        };

        func health_factor(position: BorrowPosition) : Float {
            (Float.fromInt(position.collateral) * pool.liquidity_threshold) / current_owed(position);
        };

    };

};