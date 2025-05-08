import Result "mo:base/Result";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Nat "mo:base/Nat";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Buffer "mo:base/Buffer";

import Map "mo:map/Map";

import Register "../utils/Register";
import LedgerFacade "../payement/LedgerFacade";
import Math "../utils/Math";
import Types "../Types";
import LendingPool "LendingPool";

module {

    type Account = Types.Account;
    type TxIndex = Types.TxIndex;
    type Register<T> = Types.Register<T>;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type Transfer = Types.Transfer;

    type DebtEntry = { 
        timestamp: Nat;
        amount: Float;
    };

    type BorrowPosition = {
        timestamp: Nat;
        account: Account;
        collateral_tx: [TxIndex];
        borrow_tx: [TxIndex];
        collateral: Float;
        borrowed: Float;
        borrow_index: Float;
    };

    type WithdrawEntry = {
        account: Account;
        supplied: Nat;
        due: Nat;
        var state: {
            #PENDING;
            #TRIGGERED;
            #COMPLETED;
        };
    };

    type SellCollateralQuery = ({
        amount: Nat;
        max_slippage: Float;
    }) -> async* Result<{ sold_amount: Nat }, Text>;

    // @todo: think about possible rounding errors and cast between int and float
    public class LendingManager({
        lending_pool: LendingPool.LendingPool;
        asset_ledger: LedgerFacade.LedgerFacade;
        collateral_ledger: LedgerFacade.LedgerFacade;
        sell_collateral: SellCollateralQuery;
        max_slippage: Float;
        withdraw_queue: Register<WithdrawEntry>;
        asset_accounting: {
            var reserve: Float;
            var unsolved_debts: [DebtEntry];
        };
    }) {

        public func supply({ account: Account; amount: Nat; time: Nat; }) : async* Result<(), Text> {

            switch(await* asset_ledger.transfer_from({ from = account; amount; })){
                case(#err(_)) { return #err("Transfer failed"); };
                case(#ok(_)) {};
            };

            // Need to refresh the indexes before changing the total_supply, otherwise the wrong utilization will be computed on this period?
            lending_pool.accrue_interests_and_update_rates({ time; });

            ignore lending_pool.add_supply({ position = { account; supplied = amount; }; interests = 0.0 });

            Debug.print("Supply transaction completed for account: " # debug_show(account) # " with amount: " # debug_show(amount));

            #ok;
        };

        /// This function access shall be restricted to the protocol only and called at the end of each lock
        public func withdraw({ account: Account; time: Nat; interest_share: Float; }) : Result<(), Text> {

            if (not Math.is_normalized(interest_share)) {
                return #err("Invalid interest share");
            };

            let position = switch(lending_pool.get_supply_position({ account; })){
                case(null) { return #err("Supply position not found"); };
                case(?p) { p };
            };

            // Need to refresh the indexes before changing the total_supply, otherwise the wrong utilization will be computed on this period?
            lending_pool.accrue_interests_and_update_rates({ time; });

            let interest_amount = interest_share * get_available_interests();
            let due = Float.fromInt(position.supplied) + interest_amount;

            // @todo: verify
            // In case the (negative) interests surpass the original amount supplied, remove it right away?
            if (due <= 0.0){
                Debug.print("Incredibly exceptional case where negative interests amount are greater than supply of the position");
                ignore lending_pool.slash_supply({ account; amount = position.supplied; interests = -Float.fromInt(position.supplied); });
                return #ok;
            };

            // @TODO: the state of the withdraw position shall be changed or deleted, otherwise the same position can be added in the queue many times!
            ignore Register.add<WithdrawEntry>(withdraw_queue, { account; supplied = position.supplied; due = Int.abs(Float.toInt(Float.floor(due))); var state = #PENDING; });

            Debug.print("Withdraw transaction completed for account: " # debug_show(account) # " with due amount: " # debug_show(due));
            
            #ok;
        };

        public func borrow({
            account: Account;
            amount: Nat;
            collateral: Nat;
            time: Nat
        }) : async* Result<(), Text> {

            // Refresh the indexes
            lending_pool.accrue_interests_and_update_rates({ time; });

            // Verify the utilization does not exceed the allowed limit
            let utilization = lending_pool.preview_utilization({ borrow_to_add = Float.fromInt(amount); });
            if (utilization > 1.0) {
                return #err("Utilization of " # debug_show(utilization) # " is greater than 1.0");
            };

            let position = {
                collateral = Float.fromInt(collateral);
                borrowed = Float.fromInt(amount);
                borrow_index = lending_pool.get_borrow_index();
            };

            // Verify the position's LTV
            if (not lending_pool.is_valid_ltv({ position; })) {
                return #err("LTV ratio is above current maximum");
            };

            // Transfer the collateral from the user account
            let collateral_tx = switch(await* collateral_ledger.transfer_from({ from = account; amount = collateral; })){
                case(#err(_)) { return #err("Failed to transfer collateral from the user account"); };
                case(#ok(tx)) { tx; };
            };

            // Transfer the borrow amount to the user account
            let borrow_tx = switch((await* asset_ledger.transfer({ to = account; amount = amount; })).result){
                case(#err(_)) { return #err("Failed to transfer borrow amount to the user account"); };
                case(#ok(tx)) { tx; };
            };

            // @todo: if a double borrow happen in parallel during the await, it is possible that the utilization goes greater
            // than 1. Also the borrow index will be (slightly) different after the await, which might also affect the LTV.
            // The utilization and LTV verifications shall be performed after the transfers, and the transfers shall be reverted
            // in case the verifications failed.

            ignore lending_pool.add_borrow({
                input = { 
                    position with 
                    timestamp = time;
                    account;
                    collateral_tx;
                    borrow_tx;
                };
                current_index = lending_pool.get_borrow_index();
            });

            Debug.print("Borrow transaction completed for account: " # debug_show(account) # " with amount: " # debug_show(amount));

            #ok;
        };

        public func repay({ 
            account: Account;
            amount: Nat;
            time: Nat;
        }) : async* Result<(), Text> {

            let position = switch(lending_pool.get_borrow_position({ account; })){
                case(null) { return #err("Borrow position not found"); };
                case(?p) { p };
            };

            // Refresh the indexes
            lending_pool.accrue_interests_and_update_rates({ time; });

            let owed = lending_pool.current_owed({ position; });
            let repaid_amount = Float.min(owed, Float.fromInt(amount));

            // Transfer the repayment from the user to the contract/pool
            switch(await* asset_ledger.transfer_from({ from = account; amount = Int.abs(Float.toInt(Float.ceil(repaid_amount))); })){
                case(#err(_)) { return #err("Transfer failed"); };
                case(#ok(_)) {};
            };

            // @todo: the fraction might not be accurate because what is owed will have changed after awaiting the transfer
            let repaid_fraction = repaid_amount / owed;
            let delta = repaid_fraction * position.borrowed;

            switch(lending_pool.slash_borrow({ account; borrow_amount = delta; collateral_amount = 0.0; })){
                // Reimburse collateral if the position is fully repaid
                case(null) { await* reimburse_collateral({account}); };
                // Do nothing, partial repay
                case(_) { #ok; }; 
            };
        };

        func reimburse_collateral({
            account: Account;
        }) : async* Result<(), Text> {

            let position = switch(lending_pool.get_borrow_position({ account; })){
                case(null) { return #err("Borrow position not found"); };
                case(?p) { p };
            };

            if (position.borrowed > 0.0){
                return #err("The borrow position is not fully repaid yet");
            };
                
            // Transfer back the collateral
            switch((await* collateral_ledger.transfer({ to = account; amount = Int.abs(Float.toInt(position.collateral)); })).result){
                case(#err(_)) { 
                    return #err("Collateral reimbursement failed");
                };
                case(#ok(_)) {};
            };

            #ok;
        };

        /// Liquidate borrow positions if their health factor is below 1.0.
        /// @todo: this function access shall be restricted to the protocol only and called by a timer
        public func check_all_positions_and_liquidate({ 
            time: Nat;
            collateral_spot_in_asset: () -> Float;
        }) : async*() {

            lending_pool.accrue_interests_and_update_rates({ time; });

            let to_liquidate = Buffer.Buffer<BorrowPosition>(0);
            var sum_borrowed = 0.0;
            var sum_collateral = 0.0;

            label liquidation_loop for (position in lending_pool.get_borrow_positions()){

                if (position.borrowed <= 0.0) {
                    Debug.print("The borrow position has already been repaid");
                    continue liquidation_loop;
                };

                let is_healthy = lending_pool.is_healthy({ position; });
                let is_within_borrow_duration = lending_pool.is_within_borrow_duration({ position; time; });
                
                // Liquidate if not healthy or not within the borrow duration
                if (not is_healthy or not is_within_borrow_duration){
                    to_liquidate.add(position);
                    sum_borrowed += position.borrowed;
                    sum_collateral += position.collateral;
                };
            };

            // Ceil the collateral to be sure to sell enough
            let collateral_to_sell = Int.abs(Float.toInt(Float.ceil(sum_collateral)));

            let collateral_sold = switch(await* sell_collateral({ amount = collateral_to_sell; max_slippage; })){
                case(#err(_)) { 
                    Debug.print("Collateral sale failed");
                    return; 
                };
                case(#ok({ sold_amount; })) { sold_amount; };
            };

            let ratio_sold = Float.fromInt(collateral_sold) / Float.fromInt(collateral_to_sell);

            // @todo: the total borrowed shall take the slippage into account because otherwise the
            // available total liquidity computation will be wrong (i.e. not reflect the amount actually available)
            
            // Update the positions
            for (position in to_liquidate.vals()) {
                ignore lending_pool.slash_borrow({ 
                    account = position.account;
                    borrow_amount = position.borrowed * ratio_sold;
                    collateral_amount = position.collateral * ratio_sold;
                });
            };

            let value_sold = Float.fromInt(collateral_sold) * collateral_spot_in_asset();
            let value_debt = sum_borrowed * ratio_sold;

            let difference = value_sold - value_debt;

            // @todo: need to take protocol fees

            if (difference >= 0.0) {
                asset_accounting.reserve += difference;
            } else {
                Debug.print("⚠️ Bad debt: liquidation proceeds are insufficient");
                asset_accounting.unsolved_debts := Array.append(asset_accounting.unsolved_debts, [{ timestamp = time; amount = difference; }]);
            };
        };

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

        /// This function access shall be restricted to the protocol only and called by a timer
        public func process_withdraw_queue() : async* Result<(), Text> {

            let transfers = Map.new<Nat, async* (Transfer)>();

            label process_queue for ((id, entry) in Register.entries(withdraw_queue)){

                // Ignore entries which had already been processed
                if (entry.state != #PENDING){
                    continue process_queue;
                };

                // Not enough liquidity to process the withdrawal
                if (lending_pool.available_liquidity() < Float.fromInt(entry.due)) {
                    Debug.print("Not enough liquidity to process the withdrawal");
                    break process_queue;
                };

                entry.state := #TRIGGERED;
                Map.set(transfers, Map.nhash, id, collateral_ledger.transfer({ to = entry.account; amount = entry.due; }));
                
                // @TODO: interests should not be null
                ignore lending_pool.slash_supply({ account = entry.account; amount = entry.supplied; interests = 0.0; });
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
                                // @TODO: interests should not be null
                                ignore lending_pool.add_supply({ position = { account = entry.account; supplied = entry.supplied; }; interests = 0.0; });
                            };
                        };
                    };
                };
            };

            result;
        };

        public func get_available_interests() : Float {
            lending_pool.get_supply_accrued_interests() - Array.foldLeft<DebtEntry, Float>(asset_accounting.unsolved_debts, 0.0, func (acc: Float, debt: DebtEntry) {
                acc + debt.amount;
            });
        };

    };

};