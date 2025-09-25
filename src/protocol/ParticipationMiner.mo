import Types "Types";
import LendingTypes "lending/Types";
import LedgerTypes "ledger/Types";
import Duration "duration/Duration";
import MapUtils "utils/Map";

import Debug "mo:base/Debug";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Map "mo:map/Map";
import Result "mo:base/Result";

module {

    type Duration = Types.Duration;
    type Account = Types.Account;
    type SupplyPosition = LendingTypes.SupplyPosition;
    type BorrowPosition = LendingTypes.BorrowPosition;
    type LendingIndex = LendingTypes.LendingIndex;
    type Borrow = LendingTypes.Borrow;
    type ILedgerAccount = LedgerTypes.ILedgerAccount;
    type Transfer = LedgerTypes.Transfer;
    type ParticipationTracker = Types.ParticipationTracker;
    type Buffer<T> = Buffer.Buffer<T>;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    
    type ParticipationParameters = {
        emission_half_life_s: Float;
        emission_total_amount: Nat;
        borrowers_share: Float;
    };


    public class ParticipationMiner({
        genesis_time: Nat;
        parameters: ParticipationParameters;
        minting_account: ILedgerAccount;
        supply_positions: Map.Map<Text, SupplyPosition>;
        borrow_positions: Map.Map<Account, BorrowPosition>;
        lending_index: { var value: LendingIndex; };
        register: {
            var last_mint_timestamp: Nat;
            tracking: Map.Map<Account, ParticipationTracker>;
        };
    }) {

        public func mine(now: Nat) : Result<(), Text> {

            // Ensure the current time is after the last mint timestamp
            if (now <= register.last_mint_timestamp) {
                return #err("Cannot mint with current time before or equal to last mint timestamp");
            };
            // From this point on, the last_mint_timestamp should be updated to the current time.
            // So even if an error occurs, that interval of time is considered minted and cannot be
            // claimed again. This is to avoid accumulating unminted amounts over time.
            let last_time = register.last_mint_timestamp;
            register.last_mint_timestamp := now;

            // Conversion in seconds is crucial for floating point precision in exponential calculations.
            // Using nanoseconds directly would create extremely small k values (e.g., 8e-15 for 1-day half-life)
            // which can lose precision in e^(-kt). Converting to seconds keeps values numerically stable.
            
            // Calculate k = ln(2) / T_h where T_h is half_life in seconds
            let k = Float.log(2.0) / parameters.emission_half_life_s;

            let e0 = Float.fromInt(parameters.emission_total_amount);
            
            // Calculate emission using formula: E_0 * (1 - e^(-kt))
            let unminted_at_last = e0 * Float.exp(-k * Float.fromInt(last_time - genesis_time) / Float.fromInt(Duration.NS_IN_SECOND));
            let unminted_at_now = e0 * Float.exp(-k * Float.fromInt(now - genesis_time) / Float.fromInt(Duration.NS_IN_SECOND));
            let amount_to_mint = unminted_at_last - unminted_at_now;

            Debug.print("ParticipationMiner: k = " # debug_show(k));
            Debug.print("ParticipationMiner: Half-life = " # debug_show(parameters.emission_half_life_s) # " seconds");
            Debug.print("ParticipationMiner: Amount to mint = " # debug_show(amount_to_mint) # " TWV tokens");

            if (amount_to_mint < 0) {
                return #err("Logic error: amount to mint cannot be negative");
            };

            if (amount_to_mint == 0) {
                Debug.print("No participation minting needed at this time");
                return #ok;
            };
            
            // Calculate amounts for suppliers and borrowers
            let borrowers_amount = amount_to_mint * parameters.borrowers_share;
            let suppliers_amount = amount_to_mint * (1.0 - parameters.borrowers_share);
            
            Debug.print("ParticipationMiner: Suppliers amount = " # debug_show(suppliers_amount));
            Debug.print("ParticipationMiner: Borrowers amount = " # debug_show(borrowers_amount));

            // Get current lending index
            let { raw_supplied; raw_borrowed; } = lending_index.value.utilization;
            
            // Add supplier owed amounts
            if (suppliers_amount > 0.0 and raw_supplied > 0.0) {
                accumulate_supplier_owed(suppliers_amount, raw_supplied);
            };
            
            // Add borrower owed amounts
            if (borrowers_amount > 0.0 and raw_borrowed > 0.0) {
                accumulate_borrower_owed(borrowers_amount, raw_borrowed);
            };

            #ok;
        };

        public func withdraw(account: Account) : async* ?Nat {
            let tracker = switch (Map.get(register.tracking, MapUtils.acchash, account)) {
                case (null) { 
                    Debug.print("ParticipationMiner: No participations found for account " # debug_show(account));
                    return null; 
                };
                case (?t) { t; };
            };
            
            if (tracker.owed == 0) {
                Debug.print("ParticipationMiner: No participations owed for account " # debug_show(account));
                return null;
            };
            
            Debug.print("ParticipationMiner: Attempting to claim " # debug_show(tracker.owed) # " TWV owed to " # debug_show(account));
            
            let transfer_result = await* minting_account.transfer({
                amount = tracker.owed;
                to = account;
            });
            
            let tx_id = switch (transfer_result.result) {
                case (#err(error)) {
                    Debug.print("ParticipationMiner: Failed to claim participations for " # debug_show(account) # " - Error: " # debug_show(error));
                    return null;
                };
                case (#ok(id)) { id; };
            };
            
            // Transfer successful - move from owed to received
            // TODO: add tx_id here
            let updated_tracker = {
                received = tracker.received + tracker.owed;
                owed = 0;
            };
            Map.set(register.tracking, MapUtils.acchash, account, updated_tracker);
            Debug.print("ParticipationMiner: Successfully claimed " # debug_show(tracker.owed) # " TWV for " # debug_show(account) # " - TX: " # debug_show(tx_id));
            ?tracker.owed;
        };

        public func get_trackers() : [(Account, ParticipationTracker)] {
            Map.toArray(register.tracking);
        };

        public func get_tracker(account: Account) : ?ParticipationTracker {
            Map.get(register.tracking, MapUtils.acchash, account);
        };

        func accumulate_supplier_owed(total_amount: Float, raw_supplied: Float) {
            
            for ((position_id, supply_position) in Map.entries(supply_positions)) {
                let supplied = Float.fromInt(supply_position.supplied);
                let share = supplied / raw_supplied;
                let participation_amount = total_amount * share;
                let participation_nat = Float.toInt(participation_amount);
                
                if (participation_nat > 0) {
                    add_owed(supply_position.account, Int.abs(participation_nat));
                };
            };
        };

        func accumulate_borrower_owed(total_amount: Float, raw_borrowed: Float) {
            
            for ((account, borrow_position) in Map.entries(borrow_positions)) {
                switch (borrow_position.borrow) {
                    case (null) {
                        // Skip positions without active borrows
                    };
                    case (?borrow) {
                        let borrowed = borrow.raw_amount;
                        let share = borrowed / raw_borrowed;
                        let participation_amount = total_amount * share;
                        let participation_nat = Float.toInt(participation_amount);
                        
                        if (participation_nat > 0) {
                            add_owed(account, Int.abs(participation_nat));
                        };
                    };
                };
            };
        };

        func add_owed(account: Account, amount: Nat) {
            let current_tracker = switch (Map.get(register.tracking, MapUtils.acchash, account)) {
                case (null) { { received = 0; owed = 0; }; };
                case (?tracker) { tracker; };
            };
            
            let updated_tracker = {
                current_tracker with owed = current_tracker.owed + amount;
            };
            
            Map.set(register.tracking, MapUtils.acchash, account, updated_tracker);
            Debug.print("ParticipationMiner: Updated tracker for " # debug_show(account) # " - Received: " # debug_show(updated_tracker.received) # ", Owed: " # debug_show(updated_tracker.owed));
        };


    };

};