import Types "Types";
import LendingTypes "lending/Types";
import LedgerTypes "ledger/Types";
import Duration "duration/Duration";
import MapUtils "utils/Map";

import Debug "mo:base/Debug";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Array "mo:base/Array";
import Map "mo:map/Map";

module {

    type DsnMinterParameters = Types.DsnMinterParameters;
    type Duration = Types.Duration;
    type Account = Types.Account;
    type SupplyPosition = LendingTypes.SupplyPosition;
    type BorrowPosition = LendingTypes.BorrowPosition;
    type LendingIndex = LendingTypes.LendingIndex;
    type Borrow = LendingTypes.Borrow;
    type ILedgerAccount = LedgerTypes.ILedgerAccount;
    type RewardTracker = Types.RewardTracker;
    
    type TransferInfo = {
        account: Account;
        amount: Nat;
    };

    public class DsnMinter({
        parameters: DsnMinterParameters;
        dsn_account: ILedgerAccount;
        last_mint_timestamp: { var value: Nat; };
        supply_positions: Map.Map<Text, SupplyPosition>;
        borrow_positions: Map.Map<Account, BorrowPosition>;
        lending_index: { var value: LendingIndex; };
        reward_tracking: Map.Map<Account, RewardTracker>;
    }) {

        var in_progress : Bool = false;

        public func mint(current_time: Nat) : async () {
            
            // Guard against concurrent calls - this commits state for coordination
            if (in_progress) {
                Debug.print("Mint operation already in progress");
                return;
            };
            in_progress := true;
            await checkpoint();
            
            try {
                let time_diff = do {
                    let diff : Int = current_time - last_mint_timestamp.value;
                    if (diff < 0) {
                        Debug.trap("Cannot mint with current time before last mint timestamp");
                    };
                    if (diff == 0) {
                        Debug.print("No time has passed since the last mint.");
                        return;
                    };
                    Int.abs(diff);
                };

                // Update timestamp early to prevent double-minting
                last_mint_timestamp.value := current_time;

                // Convert time_diff from nanoseconds to seconds for the formula
                // This conversion is crucial for floating point precision in exponential calculations.
                // Using nanoseconds directly would create extremely small k values (e.g., 8e-15 for 1-day half-life)
                // which can lose precision in e^(-kt). Converting to seconds keeps values numerically stable.
                let time_diff_seconds = Float.fromInt(time_diff) / Float.fromInt(Duration.NS_IN_SECOND);
                
                // Calculate k = ln(2) / T_h where T_h is half_life in seconds
                let half_life_ns = Duration.toTime(parameters.half_life);
                let half_life_seconds = Float.fromInt(half_life_ns) / Float.fromInt(Duration.NS_IN_SECOND);
                let k = Float.log(2.0) / half_life_seconds;
                
                // Calculate emission using formula: E_0 * (1 - e^(-kt))
                let initial_emission_rate = Float.fromInt(parameters.initial_emission_rate);
                let amount_to_mint = initial_emission_rate * (1.0 - Float.exp(-k * time_diff_seconds));
                
                Debug.print("DsnMinter: Amount to mint = " # debug_show(amount_to_mint) # " DSN tokens");
                Debug.print("DsnMinter: Time difference = " # debug_show(time_diff_seconds) # " seconds");
                Debug.print("DsnMinter: k = " # debug_show(k));
                Debug.print("DsnMinter: Half-life = " # debug_show(half_life_seconds) # " seconds");
                
                // Calculate amounts for suppliers and borrowers
                let borrowers_amount = amount_to_mint * parameters.borrowers_minting_ratio;
                let suppliers_amount = amount_to_mint * (1.0 - parameters.borrowers_minting_ratio);
                
                Debug.print("DsnMinter: Suppliers amount = " # debug_show(suppliers_amount));
                Debug.print("DsnMinter: Borrowers amount = " # debug_show(borrowers_amount));
                
                // Get current lending index
                let { raw_supplied; raw_borrowed; } = lending_index.value.utilization;
                
                // Collect all transfer info
                var all_transfers : [TransferInfo] = [];
                
                // Collect supplier transfers
                if (suppliers_amount > 0.0 and raw_supplied > 0.0) {
                    let supplier_transfers = collect_supplier_transfers(suppliers_amount, raw_supplied);
                    all_transfers := Array.append(all_transfers, supplier_transfers);
                };
                
                // Collect borrower transfers
                if (borrowers_amount > 0.0 and raw_borrowed > 0.0) {
                    let borrower_transfers = collect_borrower_transfers(borrowers_amount, raw_borrowed);
                    all_transfers := Array.append(all_transfers, borrower_transfers);
                };
                
                // Execute all transfers with await? and update reward tracking
                for (transfer_info in all_transfers.vals()) {
                    let result = await? dsn_account.transfer_no_commit({
                        amount = transfer_info.amount;
                        to = transfer_info.account;
                    });
                    update_reward_tracking(transfer_info.account, transfer_info.amount, result);
                };
                
                Debug.print("DsnMinter: Mint completed - processed " # debug_show(all_transfers.size()) # " transfers");
            } finally {
                in_progress := false;
            };
        };

        func collect_supplier_transfers(total_amount: Float, raw_supplied: Float) : [TransferInfo] {
            var transfers : [TransferInfo] = [];
            
            for ((position_id, supply_position) in Map.entries(supply_positions)) {
                let supplied = Float.fromInt(supply_position.supplied);
                let share = supplied / raw_supplied;
                let reward_amount = total_amount * share;
                let reward_nat = Float.toInt(reward_amount);
                
                if (reward_nat > 0) {
                    let account = supply_position.account;
                    let reward_amount = Int.abs(reward_nat);
                    
                    Debug.print("DsnMinter: Preparing transfer of " # debug_show(reward_amount) # " DSN to supplier " # debug_show(account) # " (share: " # debug_show(share) # ")");
                    
                    let transfer_info : TransferInfo = {
                        account;
                        amount = reward_amount;
                    };
                    
                    transfers := Array.append(transfers, [transfer_info]);
                };
            };
            transfers;
        };

        func collect_borrower_transfers(total_amount: Float, raw_borrowed: Float) : [TransferInfo] {
            var transfers : [TransferInfo] = [];
            
            for ((account, borrow_position) in Map.entries(borrow_positions)) {
                switch (borrow_position.borrow) {
                    case (null) {
                        // Skip positions without active borrows
                    };
                    case (?borrow) {
                        let borrowed = borrow.raw_amount;
                        let share = borrowed / raw_borrowed;
                        let reward_amount = total_amount * share;
                        let reward_nat = Float.toInt(reward_amount);
                        
                        if (reward_nat > 0) {
                            let reward_amount = Int.abs(reward_nat);
                            
                            Debug.print("DsnMinter: Preparing transfer of " # debug_show(reward_amount) # " DSN to borrower " # debug_show(account) # " (share: " # debug_show(share) # ")");
                            
                            let transfer_info : TransferInfo = {
                                account;
                                amount = reward_amount;
                            };
                            
                            transfers := Array.append(transfers, [transfer_info]);
                        };
                    };
                };
            };
            transfers;
        };

        func update_reward_tracking(account: Account, amount: Nat, transfer_result: LedgerTypes.Transfer) {
            let current_tracker = switch (Map.get(reward_tracking, MapUtils.acchash, account)) {
                case (null) { { rewards_received = 0; rewards_owed = 0; }; };
                case (?tracker) { tracker; };
            };
            
            let updated_tracker = switch (transfer_result.result) {
                case (#ok(_)) {
                    Debug.print("DsnMinter: Transfer successful - " # debug_show(amount) # " DSN to " # debug_show(account));
                    { current_tracker with rewards_received = current_tracker.rewards_received + amount; };
                };
                case (#err(error)) {
                    Debug.print("DsnMinter: Transfer failed - " # debug_show(amount) # " DSN owed to " # debug_show(account) # " - Error: " # debug_show(error));
                    { current_tracker with rewards_owed = current_tracker.rewards_owed + amount; };
                };
            };
            
            Map.set(reward_tracking, MapUtils.acchash, account, updated_tracker);
            Debug.print("DsnMinter: Updated tracker for " # debug_show(account) # " - Received: " # debug_show(updated_tracker.rewards_received) # ", Owed: " # debug_show(updated_tracker.rewards_owed));
        };

        public func claim_rewards_owed(account: Account) : async* ?Nat {
            let tracker = switch (Map.get(reward_tracking, MapUtils.acchash, account)) {
                case (null) { 
                    Debug.print("DsnMinter: No rewards found for account " # debug_show(account));
                    return null; 
                };
                case (?t) { t; };
            };
            
            if (tracker.rewards_owed == 0) {
                Debug.print("DsnMinter: No rewards owed for account " # debug_show(account));
                return null;
            };
            
            Debug.print("DsnMinter: Attempting to claim " # debug_show(tracker.rewards_owed) # " DSN owed to " # debug_show(account));
            
            let transfer_result = await* dsn_account.transfer({
                amount = tracker.rewards_owed;
                to = account;
            });
            
            let tx_id = switch (transfer_result.result) {
                case (#err(error)) {
                    Debug.print("DsnMinter: Failed to claim rewards for " # debug_show(account) # " - Error: " # debug_show(error));
                    return null;
                };
                case (#ok(id)) { id; };
            };
            
            // Transfer successful - move from owed to received
            let updated_tracker = {
                rewards_received = tracker.rewards_received + tracker.rewards_owed;
                rewards_owed = 0;
            };
            Map.set(reward_tracking, MapUtils.acchash, account, updated_tracker);
            Debug.print("DsnMinter: Successfully claimed " # debug_show(tracker.rewards_owed) # " DSN for " # debug_show(account) # " - TX: " # debug_show(tx_id));
            ?tracker.rewards_owed;
        };

        public func get_reward_tracker(account: Account) : ?RewardTracker {
            Map.get(reward_tracking, MapUtils.acchash, account);
        };

        private func checkpoint() : async () {
            // intentionally empty; awaiting this commits state
        };

    };

};