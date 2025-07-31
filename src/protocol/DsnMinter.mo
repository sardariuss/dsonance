import Types "Types";
import LendingTypes "lending/Types";
import LedgerTypes "ledger/Types";
import Duration "duration/Duration";
import MapUtils "utils/Map";

import Debug "mo:base/Debug";
import Float "mo:base/Float";
import Int "mo:base/Int";
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

    public class DsnMinter({
        parameters: DsnMinterParameters;
        dsn_account: ILedgerAccount;
        last_mint_timestamp: { var value: Nat; };
        supply_positions: Map.Map<Text, SupplyPosition>;
        borrow_positions: Map.Map<Account, BorrowPosition>;
        lending_index: { var value: LendingIndex; };
        accumulated_rewards: Map.Map<Account, Nat>;
    }) {

        public func mint(current_time: Nat) : async* () {
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
            
            // Distribute to suppliers
            if (suppliers_amount > 0.0 and raw_supplied > 0.0) {
                await* distribute_to_suppliers(suppliers_amount, raw_supplied);
            };
            
            // Distribute to borrowers
            if (borrowers_amount > 0.0 and raw_borrowed > 0.0) {
                await* distribute_to_borrowers(borrowers_amount, raw_borrowed);
            };
            
            // Update the last mint timestamp
            last_mint_timestamp.value := current_time;
        };

        func distribute_to_suppliers(total_amount: Float, raw_supplied: Float) : async* () {
            for ((position_id, supply_position) in Map.entries(supply_positions)) {
                let supplied = Float.fromInt(supply_position.supplied);
                let share = supplied / raw_supplied;
                let reward_amount = total_amount * share;
                let reward_nat = Float.toInt(reward_amount);
                
                if (reward_nat > 0) {
                    let account = supply_position.account;
                    let reward_amount = Int.abs(reward_nat);
                    
                    // Update accumulated rewards
                    let current_accumulated = switch (Map.get(accumulated_rewards, MapUtils.acchash, account)) {
                        case (null) { 0; };
                        case (?amount) { amount; };
                    };
                    Map.set(accumulated_rewards, MapUtils.acchash, account, current_accumulated + reward_amount);
                    
                    Debug.print("DsnMinter: Transferring " # debug_show(reward_amount) # " DSN to supplier " # debug_show(account) # " (share: " # debug_show(share) # ", total accumulated: " # debug_show(current_accumulated + reward_amount) # ")");
                    
                    ignore await* dsn_account.transfer({
                        amount = reward_amount;
                        to = account;
                    });
                };
            };
        };

        func distribute_to_borrowers(total_amount: Float, raw_borrowed: Float) : async* () {
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
                            
                            // Update accumulated rewards
                            let current_accumulated = switch (Map.get(accumulated_rewards, MapUtils.acchash, account)) {
                                case (null) { 0; };
                                case (?amount) { amount; };
                            };
                            Map.set(accumulated_rewards, MapUtils.acchash, account, current_accumulated + reward_amount);
                            
                            Debug.print("DsnMinter: Transferring " # debug_show(reward_amount) # " DSN to borrower " # debug_show(account) # " (share: " # debug_show(share) # ", total accumulated: " # debug_show(current_accumulated + reward_amount) # ")");
                            
                            ignore await* dsn_account.transfer({
                                amount = reward_amount;
                                to = account;
                            });
                        };
                    };
                };
            };
        };

    };

};