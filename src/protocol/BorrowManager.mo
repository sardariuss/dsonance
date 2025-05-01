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
        reserve_factor: Float; // portion of supply reserved (0.0 to 1.0, e.g., 0.1 for 10%)
        var total_deposit: Nat; // total deposits
        var total_collateral: Nat; // total collateral
        var total_borrowed: Float; // total borrowed
        var borrow_index: Float; // growing value, starts at 1.0
        var last_update_timestamp: Nat; // Timestamp in nanoseconds
        var accrued_interest: Float;
    };

    public class BorrowManager({
        borrow_ledger: LedgerFacade.LedgerFacade;
        collateral_ledger: LedgerFacade.LedgerFacade;
        pool: LendingPoolState;
        interestRateCurve: InterestRateCurve.InterestRateCurve;
        positions: Map.Map<Account, BorrowPosition>;
    }) {

        func refresh_interest({ time: Nat; }) {

            let elapsed : Int = time - pool.last_update_timestamp;

            // If the time is before the last update
            if (elapsed < 0) {
                Debug.trap("Cannot update rate: time is before last update");
            } else if (elapsed == 0) {
                Debug.print("Rate is already up to date");
                return;
            };

            // Calculate utilization ratio
            let utilization = do {
                if (pool.total_deposit == 0) {
                    // If total deposit is 0, utilization is technically undefined or 0.
                    0.0;
                } else {
                    pool.total_borrowed / Float.fromInt(pool.total_deposit);
                };
            };

            // Clamp utilization between 0.0 and 1.0 as a safeguard
            let clamped_utilization = Float.max(0.0, Float.min(1.0, utilization));

            // Get the current interest rate from the curve
            let current_rate_percent = interestRateCurve.get_current_rate(clamped_utilization);
            let current_rate_ratio = Math.percentageToRatio(current_rate_percent); // Convert e.g. 5.0 to 0.05

            // Calculate the time period in years
            let annual_period = Duration.toAnnual(Duration.getDuration({ from = pool.last_update_timestamp; to = time; }));

            pool.accrued_interest += pool.total_borrowed * current_rate_ratio * annual_period;
            pool.borrow_index *= (1.0 + current_rate_ratio * annual_period);
            pool.last_update_timestamp := time;
        };

        func refresh_borrow_position(position: BorrowPosition, time: Nat) {
            refresh_interest({ time });

            // Accrue position's current debt
            let diff = position.borrowed * (1.0 - pool.borrow_index / position.borrow_index);
            position.borrowed += diff;
            position.borrow_index := pool.borrow_index;

            // Update the total_borrowed in the pool
            pool.total_borrowed += diff;
        };

        public func borrow({
            account: Account;
            borrowAmount: Nat;
            collateralAmount: Nat;
            time: Nat
        }) : async* Result<(), Text> {

            // Transfer the collateral from the user account
            let collateral_tx = switch(await* collateral_ledger.transfer_from({ from = account; amount = collateralAmount; })){
                case(#err(_)) { return #err("Failed to transfer collateral from the user account"); };
                case(#ok(tx)) { tx; };
            };

            // Transfer the borrow amount to the user account
            let borrow_tx = switch((await* borrow_ledger.transfer({ to = account; amount = borrowAmount; })).result){
                case(#err(_)) { return #err("Failed to transfer borrow amount to the user account"); };
                case(#ok(tx)) { tx; };
            };

            switch(Map.get(positions, MapUtils.acchash, account)){
                case(null){
                    Map.set(positions, MapUtils.acchash, account, {
                        account;
                        var collateral_tx = [collateral_tx];
                        var borrow_tx = [borrow_tx];
                        var collateral = collateralAmount;
                        var borrowed = Float.fromInt(borrowAmount);
                        var borrow_index = pool.borrow_index;
                    });
                };
                case(?position){
                    // Refresh the position
                    refresh_borrow_position(position, time);

                    // Update the position
                    position.collateral_tx := Array.append(position.collateral_tx, [collateral_tx]);
                    position.borrow_tx := Array.append(position.borrow_tx, [borrow_tx]);
                    position.collateral += collateralAmount;
                    position.borrowed += Float.fromInt(borrowAmount);
                };
            };

            pool.total_borrowed += Float.fromInt(borrowAmount);
            pool.total_collateral += collateralAmount;

            #ok;
        };

        public func repay({ 
            account: Account;
            amount: Nat;
            time: Nat;
        }) : async* Result<(), Text> {

            let position = switch (Map.get<Account, BorrowPosition>(positions, MapUtils.acchash, account)) {
                case (null) { return #err("Position not found"); };
                case (?p) { p; };
            };

            // Refresh the position
            refresh_borrow_position(position, time);

            let actual_amount = Float.min(position.borrowed, Float.fromInt(amount));

            // Transfer the repayment from the user to the contract/pool
            switch(await* borrow_ledger.transfer_from({ from = account; amount = Int.abs(Float.toInt(Float.ceil(actual_amount))); })){
                case(#err(_)) { return #err("Transfer failed"); };
                case(#ok(_)) {};
            };
            position.borrowed := position.borrowed - actual_amount;
            pool.total_borrowed -= actual_amount;

            await* reimburse_collateral({account});
        };

        public func reimburse_collateral({
            account: Account;
        }) : async* Result<(), Text> {

            let position = switch (Map.get<Account, BorrowPosition>(positions, MapUtils.acchash, account)) {
                case (null) { return #err("Position not found"); };
                case (?p) { p; };
            };

            if (position.borrowed > 0.0){
                return #err("Borrow amount must be greater than zero");
            };
                
            // Transfer back the collateral
            switch((await* collateral_ledger.transfer({ to = account; amount = position.collateral; })).result){
                case(#err(_)) { 
                    // @todo: need a method to try reimburse collateral which transfer failed
                    return #err("Collateral reimbursement failed");
                };
                case(#ok(_)) {};
            };

            pool.total_collateral -= position.collateral;
            Map.delete(positions, MapUtils.acchash, account);

            #ok;
        };

        /// Liquidate a borrow position if its health factor is below 1.0.
        public func liquidate({ borrower: Account;  time: Nat; }) : async* Result<(), Text> {

            let position = switch (Map.get<Account, BorrowPosition>(positions, MapUtils.acchash, borrower)) {
                case (null) { return #err("No borrow position found for borrower"); };
                case (?p) { p; };
            };

            // Refresh the position
            refresh_borrow_position(position, time);

            if (position.borrowed <= 0.0) {
                return #err("Borrow amount must be greater than zero");
            };
            
            // Determine position's health factor
            let healthFactor = (Float.fromInt(position.collateral) * pool.liquidity_threshold) / position.borrowed;
            if (healthFactor >= 1.0) {
                return #err("Position is still healthy");
            };

            // @todo: Sell collateral

            Map.delete(positions, MapUtils.acchash, borrower);
            pool.total_borrowed -= position.borrowed;
            pool.total_collateral -= position.collateral;

            #ok;
        };

    };

};