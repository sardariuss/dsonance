import Types "Types";
import LendingTypes "lending/Types";
import LedgerTypes "ledger/Types";
import Duration "duration/Duration";
import MapUtils "utils/Map";
import RollingTimeline "utils/RollingTimeline";

import Debug "mo:base/Debug";
import Float "mo:base/Float";
import Int "mo:base/Int";
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
    type MiningTracker = Types.MiningTracker;
    type Buffer<T> = Buffer.Buffer<T>;
    type Result<Ok, Err> = Result.Result<Ok, Err>;

    type MiningParameters = {
        emission_half_life_s: Float;
        emission_total_amount_e8s: Nat;
        borrowers_share: Float;
    };

    public class Miner({
        genesis_time: Nat;
        parameters: MiningParameters;
        minting_account: ILedgerAccount;
        supply_positions: Map.Map<Text, SupplyPosition>;
        borrow_positions: Map.Map<Account, BorrowPosition>;
        lending_index: { var value: LendingIndex; };
        register: {
            var last_mint_timestamp: Nat;
            tracking: Map.Map<Account, MiningTracker>;
            total_allocated: RollingTimeline.RollingTimeline<Nat>;
            total_claimed: RollingTimeline.RollingTimeline<Nat>;
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

            let e0 = Float.fromInt(parameters.emission_total_amount_e8s);
            
            // Calculate emission using formula: E_0 * (1 - e^(-kt))
            let unminted_at_last = e0 * Float.exp(-k * Float.fromInt(last_time - genesis_time) / Float.fromInt(Duration.NS_IN_SECOND));
            let unminted_at_now = e0 * Float.exp(-k * Float.fromInt(now - genesis_time) / Float.fromInt(Duration.NS_IN_SECOND));
            let amount_to_mint = unminted_at_last - unminted_at_now;

            Debug.print("Miner: k = " # debug_show(k));
            Debug.print("Miner: Half-life = " # debug_show(parameters.emission_half_life_s) # " seconds");
            Debug.print("Miner: Amount to mint = " # debug_show(amount_to_mint) # " TWV tokens");

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
            
            Debug.print("Miner: Suppliers amount = " # debug_show(suppliers_amount));
            Debug.print("Miner: Borrowers amount = " # debug_show(borrowers_amount));

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

        public func withdraw(account: Account, now: Nat) : async* ?Nat {
            let tracker = switch (Map.get(register.tracking, MapUtils.acchash, account)) {
                case (null) {
                    Debug.print("Miner: No mining rewards found for account " # debug_show(account));
                    return null;
                };
                case (?t) { t; };
            };

            if (tracker.allocated == 0) {
                Debug.print("Miner: No mining rewards allocated for account " # debug_show(account));
                return null;
            };

            Debug.print("Miner: Attempting to claim " # debug_show(tracker.allocated) # " TWV allocated to " # debug_show(account));

            let transfer_result = await* minting_account.transfer({
                amount = tracker.allocated;
                to = account;
            });

            let tx_id = switch (transfer_result.result) {
                case (#err(error)) {
                    Debug.print("Miner: Failed to claim mining rewards for " # debug_show(account) # " - Error: " # debug_show(error));
                    return null;
                };
                case (#ok(id)) { id; };
            };

            // Transfer successful - move from allocated to claimed
            // TODO: add tx_id here
            let withdrawn_amount = tracker.allocated;
            let updated_tracker = {
                claimed = tracker.claimed + withdrawn_amount;
                allocated = 0;
            };
            Map.set(register.tracking, MapUtils.acchash, account, updated_tracker);

            // Update total_claimed timeline
            let current_total_claimed = RollingTimeline.current(register.total_claimed);
            let new_total_claimed = current_total_claimed + withdrawn_amount;
            RollingTimeline.insert(register.total_claimed, now, new_total_claimed);

            Debug.print("Miner: Successfully withdrawn " # debug_show(withdrawn_amount) # " TWV for " # debug_show(account) # " - TX: " # debug_show(tx_id));
            ?withdrawn_amount;
        };

        public func get_trackers() : [(Account, MiningTracker)] {
            Map.toArray(register.tracking);
        };

        public func get_tracker(account: Account) : ?MiningTracker {
            Map.get(register.tracking, MapUtils.acchash, account);
        };

        public func get_total_allocated() : RollingTimeline.RollingTimeline<Nat> {
            register.total_allocated;
        };

        public func get_total_claimed() : RollingTimeline.RollingTimeline<Nat> {
            register.total_claimed;
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
                case (null) { { claimed = 0; allocated = 0; }; };
                case (?tracker) { tracker; };
            };

            let updated_tracker = {
                current_tracker with allocated = current_tracker.allocated + amount;
            };

            Map.set(register.tracking, MapUtils.acchash, account, updated_tracker);

            // Update total_allocated timeline
            let current_total_allocated = RollingTimeline.current(register.total_allocated);
            let new_total_allocated = current_total_allocated + amount;
            RollingTimeline.insert(register.total_allocated, register.last_mint_timestamp, new_total_allocated);

            Debug.print("Miner: Updated tracker for " # debug_show(account) # " - Claimed: " # debug_show(updated_tracker.claimed) # ", Allocated: " # debug_show(updated_tracker.allocated));
        };


    };

};