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

    type TransferInfo = {
        account: Account;
        amount: Nat;
    };

    public class ParticipationMinter({
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

        var minting : Bool = false;

        public func mint(now: Nat) : async* Result<(), Text> {

            // Guard against concurrent calls
            if (minting) {
                return #err("Mint operation already in progress");
            };
            minting := true;
            // Ensure the minting flag is committed before proceeding because await?
            // is used later in the function.
            // This is crucial to prevent re-entrancy issues.
            await* checkpoint();

            try {
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

                Debug.print("ParticipationMinter: k = " # debug_show(k));
                Debug.print("ParticipationMinter: Half-life = " # debug_show(parameters.emission_half_life_s) # " seconds");
                Debug.print("ParticipationMinter: Amount to mint = " # debug_show(amount_to_mint) # " DSN tokens");

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
                
                Debug.print("ParticipationMinter: Suppliers amount = " # debug_show(suppliers_amount));
                Debug.print("ParticipationMinter: Borrowers amount = " # debug_show(borrowers_amount));

                // Get current lending index
                let { raw_supplied; raw_borrowed; } = lending_index.value.utilization;

                // Collect all transfer info
                var infos : [TransferInfo] = [];
                
                // Collect supplier transfers
                if (suppliers_amount > 0.0 and raw_supplied > 0.0) {
                    let supplier_transfers = collect_supplier_transfers(suppliers_amount, raw_supplied);
                    infos := Array.append(infos, supplier_transfers);
                };
                
                // Collect borrower transfers
                if (borrowers_amount > 0.0 and raw_borrowed > 0.0) {
                    let borrower_transfers = collect_borrower_transfers(borrowers_amount, raw_borrowed);
                    infos := Array.append(infos, borrower_transfers);
                };

                if (infos.size() == 0) {
                    Debug.print("No participations to mint, skipping transfer");
                    return #ok;
                };

                // Fire off all transfers concurrently
                let transfers = Buffer.Buffer<{ info: TransferInfo; transfer: async Transfer }>(infos.size());
                for (info in infos.vals()) {
                    let transfer = minting_account.transfer_no_commit({
                        amount = info.amount;
                        to = info.account;
                    });
                    transfers.add({ info; transfer });
                };

                // Await all transfers to complete
                for ({ info; transfer; } in transfers.vals()) {
                    update_tracking(info.account, info.amount, await? transfer);
                };

                Debug.print("ParticipationMinter: Mint completed - processed " # debug_show(infos.size()) # " transfers");
                #ok;
            } finally {
                minting := false;
            };
        };

        public func claim_owed(account: Account) : async* ?Nat {
            let tracker = switch (Map.get(register.tracking, MapUtils.acchash, account)) {
                case (null) { 
                    Debug.print("ParticipationMinter: No participations found for account " # debug_show(account));
                    return null; 
                };
                case (?t) { t; };
            };
            
            if (tracker.owed == 0) {
                Debug.print("ParticipationMinter: No participations owed for account " # debug_show(account));
                return null;
            };
            
            Debug.print("ParticipationMinter: Attempting to claim " # debug_show(tracker.owed) # " DSN owed to " # debug_show(account));
            
            let transfer_result = await* minting_account.transfer({
                amount = tracker.owed;
                to = account;
            });
            
            let tx_id = switch (transfer_result.result) {
                case (#err(error)) {
                    Debug.print("ParticipationMinter: Failed to claim participations for " # debug_show(account) # " - Error: " # debug_show(error));
                    return null;
                };
                case (#ok(id)) { id; };
            };
            
            // Transfer successful - move from owed to received
            let updated_tracker = {
                received = tracker.received + tracker.owed;
                owed = 0;
            };
            Map.set(register.tracking, MapUtils.acchash, account, updated_tracker);
            Debug.print("ParticipationMinter: Successfully claimed " # debug_show(tracker.owed) # " DSN for " # debug_show(account) # " - TX: " # debug_show(tx_id));
            ?tracker.owed;
        };

        public func get_trackers() : [(Account, ParticipationTracker)] {
            Map.toArray(register.tracking);
        };

        public func get_tracker(account: Account) : ?ParticipationTracker {
            Map.get(register.tracking, MapUtils.acchash, account);
        };

        func collect_supplier_transfers(total_amount: Float, raw_supplied: Float) : [TransferInfo] {
            var transfers : [TransferInfo] = [];
            
            for ((position_id, supply_position) in Map.entries(supply_positions)) {
                let supplied = Float.fromInt(supply_position.supplied);
                let share = supplied / raw_supplied;
                let participation_amount = total_amount * share;
                let participation_nat = Float.toInt(participation_amount);
                
                if (participation_nat > 0) {
                    let account = supply_position.account;
                    let participation_amount = Int.abs(participation_nat);
                    
                    Debug.print("ParticipationMinter: Preparing transfer of " # debug_show(participation_amount) # " DSN to supplier " # debug_show(account) # " (share: " # debug_show(share) # ")");
                    
                    let transfer_info : TransferInfo = {
                        account;
                        amount = participation_amount;
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
                        let participation_amount = total_amount * share;
                        let participation_nat = Float.toInt(participation_amount);
                        
                        if (participation_nat > 0) {
                            let participation_amount = Int.abs(participation_nat);
                            
                            Debug.print("ParticipationMinter: Preparing transfer of " # debug_show(participation_amount) # " DSN to borrower " # debug_show(account) # " (share: " # debug_show(share) # ")");
                            
                            let transfer_info : TransferInfo = {
                                account;
                                amount = participation_amount;
                            };
                            
                            transfers := Array.append(transfers, [transfer_info]);
                        };
                    };
                };
            };
            transfers;
        };

        func update_tracking(account: Account, amount: Nat, transfer_result: LedgerTypes.Transfer) {
            let current_tracker = switch (Map.get(register.tracking, MapUtils.acchash, account)) {
                case (null) { { received = 0; owed = 0; }; };
                case (?tracker) { tracker; };
            };
            
            let updated_tracker = switch (transfer_result.result) {
                case (#ok(_)) {
                    Debug.print("ParticipationMinter: Transfer successful - " # debug_show(amount) # " DSN to " # debug_show(account));
                    { current_tracker with received = current_tracker.received + amount; };
                };
                case (#err(error)) {
                    Debug.print("ParticipationMinter: Transfer failed - " # debug_show(amount) # " DSN owed to " # debug_show(account) # " - Error: " # debug_show(error));
                    { current_tracker with owed = current_tracker.owed + amount; };
                };
            };
            
            Map.set(register.tracking, MapUtils.acchash, account, updated_tracker);
            Debug.print("ParticipationMinter: Updated tracker for " # debug_show(account) # " - Received: " # debug_show(updated_tracker.received) # ", Owed: " # debug_show(updated_tracker.owed));
        };

        func checkpoint() : async* () {
            // intentionally empty; awaiting this commits state
        };

    };

};