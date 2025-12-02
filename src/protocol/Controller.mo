import Types                   "Types";
import LockScheduler           "LockScheduler";
import Miner                   "Miner";
import MapUtils                "utils/Map";
import RollingTimeline         "utils/RollingTimeline";
import Clock                   "utils/Clock";
import SharedConversions       "shared/SharedConversions";
import PositionUtils           "pools/PositionUtils";
import PoolTypeController      "pools/PoolTypeController";
import IdFormatter             "IdFormatter";
import IterUtils               "utils/Iter";
import LedgerTypes             "ledger/Types";
import LendingTypes            "lending/Types";
import RedistributionHub       "lending/RedistributionHub";
import BorrowRegistry          "lending/BorrowRegistry";
import WithdrawalQueue         "lending/WithdrawalQueue";
import SupplyAccount           "lending/SupplyAccount";
import ForesightUpdater        "ForesightUpdater";

import Map                     "mo:map/Map";
import Set                     "mo:map/Set";

import Int                     "mo:base/Int";
import Float                   "mo:base/Float";
import Debug                   "mo:base/Debug";
import Result                  "mo:base/Result";
import Principal               "mo:base/Principal";

module {

    type Time = Int;
    type PoolRegister = Types.PoolRegister;
    type PoolType = Types.PoolType;
    type PositionType = Types.PositionType;
    type PutPositionResult = Types.PutPositionResult;
    type ChoiceType = Types.ChoiceType;
    type Account = Types.Account;
    type UUID = Types.UUID;
    type SNewPoolResult = Types.SNewPoolResult;
    type PositionRegister = Types.PositionRegister;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type Parameters = Types.Parameters;
    type RollingTimeline<T> = Types.RollingTimeline<T>;
    type ProtocolInfo = Types.ProtocolInfo;
    type YesNoPosition = Types.YesNoPosition;
    type YesNoPool = Types.YesNoPool;
    type Lock = Types.Lock;
    type Duration = Types.Duration;
    type YieldState = Types.YieldState;
    type PutPositionError = Types.PutPositionError;
    type LoanPosition = LendingTypes.LoanPosition;
    type Loan = LendingTypes.Loan;
    type BorrowOperation = LendingTypes.BorrowOperation;
    type BorrowOperationArgs = LendingTypes.BorrowOperationArgs;
    type TransferResult = LendingTypes.TransferResult;
    type IPriceTracker = LedgerTypes.IPriceTracker;
    type MiningTracker = Types.MiningTracker;

    type Iter<T> = Map.Iter<T>;
    type Map<K, V> = Map.Map<K, V>;
    type Set<T> = Set.Set<T>;

    type WeightParams = {
        position: PositionType;
        update_position: (PositionType) -> ();
        weight: Float;
    };

    public type NewPoolArgs = {
        id: UUID;
        origin: Principal;
        type_enum: Types.PoolTypeEnum;
        account: Account;
    };

    public type PutPositionArgs = {
        id: UUID;
        pool_id: UUID;
        choice_type: ChoiceType;
        caller: Principal;
        from_subaccount: ?Blob;
        amount: Nat;
    };

    type PutLimitOrderArgs = {
        order_id: Types.UUID;
        pool_id: Types.UUID;
        account: Account;
        amount: Nat;
        choice: Types.ChoiceType;
        limit_dissent: Float;
    };

    public type PutPositionPreviewArgs = PutPositionArgs and {
        // If true, the preview will take into account the impact of the position on the supply APY
        // If false, the preview will not take into account this impact
        with_supply_apy_impact: Bool;
    };

    public class Controller({
        genesis_time: Nat;
        clock: Clock.Clock;
        pool_register: PoolRegister;
        position_register: PositionRegister;
        lock_scheduler: LockScheduler.LockScheduler;
        pool_type_controller: PoolTypeController.PoolTypeController;
        supply: SupplyAccount.SupplyAccount;
        redistribution_hub: RedistributionHub.RedistributionHub;
        borrow_registry: BorrowRegistry.BorrowRegistry;
        withdrawal_queue: WithdrawalQueue.WithdrawalQueue;
        collateral_price_tracker: IPriceTracker;
        collateral_usd_price_tracker: { fetch_price: () -> async* Result<(), Text>; get_token_price_usd: () -> Float };
        supply_usd_price_tracker: { fetch_price: () -> async* Result<(), Text>; get_token_price_usd: () -> Float };
        miner: Miner.Miner;
        parameters: Parameters;
        foresight_updater: ForesightUpdater.ForesightUpdater;
    }){

        public func new_pool(args: NewPoolArgs) : async* SNewPoolResult {

            let { type_enum; origin; id; account; } = args;

            let pool_id = IdFormatter.format(#Pool(id));

            if (Map.has(pool_register.pools, Map.thash, pool_id)){
                return #err("Pool already exists: " # pool_id);
            };

            // Add the pool
            let pool = pool_type_controller.new_pool({
                pool_id;
                tx_id = 0; // @todo: for now everyone can create a pool without a transfer
                pool_type_enum = type_enum;
                date = clock.get_time();
                origin;
                author = account;
            });
            Map.set(pool_register.pools, Map.thash, pool_id, pool);

            // Update the by_origin and by_author maps
            MapUtils.putInnerSet(pool_register.by_origin, Map.phash, origin, Map.thash, pool_id);
            MapUtils.putInnerSet(pool_register.by_author, MapUtils.acchash, account, Map.thash, pool_id);
            
            // TODO: ideally it's not the controller's responsibility to share types
            #ok(SharedConversions.sharePoolType(pool));
        };

        // This function is made to allow the frontend to preview the result of put_position
        // TODO: ideally one should have a true preview function that does not mutate the state
        public func put_position_for_free(args: PutPositionPreviewArgs) : PutPositionResult {

            let timestamp = clock.get_time();

            let { position_id; pool_type; } = switch(process_position_input(args)){
                case(#err(err)) { return #err(err); };
                case(#ok(input)) { input; };
            };

            // If with_supply_apy_impact is true, the preview will take into account
            // the impact of the position on the supply APY
            let supplied = do {
                if (args.with_supply_apy_impact) args.amount else 0;
            };

            let preview_result = redistribution_hub.add_position_without_transfer({
                id = position_id;
                account = { owner = args.caller; subaccount = args.from_subaccount; };
                supplied;
            }, timestamp);

            let { tx_id; supply_index; } = switch(preview_result){
                case(#err(err)) { return #err(err); };
                case(#ok(ok)) { ok; };
            };

            perform_put_position({
                args;
                timestamp;
                pool_type;
                position_id;
                tx_id;
                supply_index;
            });
        };

        public func put_position(args: PutPositionArgs) : async* PutPositionResult {

            if (Principal.isAnonymous(args.caller)) {
                return #err("Anonymous caller cannot put a position");
            };

            let { position_id; pool_type; } = switch(process_position_input(args)){
                case(#err(err)) { return #err(err); };
                case(#ok(input)) { input; };
            };

            // Capture timestamp before the transfer for the indexer
            let timestamp_before_transfer = clock.get_time();

            let transfer = await* redistribution_hub.add_position({
                id = position_id;
                account = { owner = args.caller; subaccount = args.from_subaccount; };
                supplied = args.amount;
            }, timestamp_before_transfer);

            let { tx_id; supply_index; } = switch(transfer){
                case(#err(err)) { return #err(err); };
                case(#ok(ok)) { ok; };
            };

            // Recapture timestamp after the async operation for the position
            let timestamp = clock.get_time();

            perform_put_position({
                args;
                timestamp;
                pool_type;
                position_id;
                tx_id;
                supply_index;
            });
        };

        public func put_limit_order(args: PutLimitOrderArgs) : async Result<(), Text> {

            let { order_id; pool_id; account; amount; limit_dissent; } = args;

            if (Principal.isAnonymous(account.owner)) {
                return #err("Anonymous caller cannot put a position");
            };

            let pool_type = switch(Map.get(pool_register.pools, Map.thash, pool_id)){
                case(null) return #err("Pool not found: " # pool_id);
                case(?v) v;
            };

            if (limit_dissent < 0.0 or limit_dissent > 1.0) {
                return #err("Limit dissent must be between 0.0 and 1.0");
            };

            if (amount < parameters.minimum_position_amount){
                return #err("Insufficient amount: " # debug_show(amount) # " (minimum: " # debug_show(parameters.minimum_position_amount) # ")");
            };

            // Capture timestamp before the transfer for the indexer
            let timestamp_before_transfer = clock.get_time();

            let transfer = await* redistribution_hub.add_position({
                id = order_id;
                account = account;
                supplied = amount;
            }, timestamp_before_transfer);

            switch(transfer){
                case(#err(err)) { return #err(err); };
                case(_) {};
            };

            // Recapture timestamp after the async operation for the position
            let timestamp = clock.get_time();

            pool_type_controller.put_limit_order({
                pool_type;
                args = { args with timestamp; };
            });

            #ok;
        };

        public func run_borrow_operation(args: BorrowOperationArgs) : async* Result<BorrowOperation, Text> {
            await* borrow_registry.run_operation(clock.get_time(), args);
        };

        public func run_borrow_operation_for_free(args: BorrowOperationArgs) : Result<BorrowOperation, Text> {
            borrow_registry.run_operation_for_free(clock.get_time(), args);
        };

        public func get_loan_position(account: Account) : LoanPosition {
            borrow_registry.get_loan_position(clock.get_time(), account);
        };

        public func get_loans_info() : { positions: [Loan]; max_ltv: Float } {
            borrow_registry.get_loans_info(clock.get_time());
        };

        public func get_available_liquidities() : async* Nat {
            await* supply.get_available_liquidities();
        };

        public func get_unclaimed_fees() : Nat {
            supply.get_unclaimed_fees();
        };

        public func withdraw_fees({ caller: Principal; to: Account; amount: Nat; }) : async* TransferResult {
            await* supply.withdraw_fees({ caller; to; amount; });
        };

        // TODO: make sure none of the methods called in this function can trap:
        // it should only log errors
        public func run() : async* () {

            var time = clock.get_time();
            Debug.print("Running controller at time: " # debug_show(time));

            // 1. Fetch USD prices
            switch(await* collateral_usd_price_tracker.fetch_price()){
                case(#err(error)) { Debug.print("Failed to fetch collateral USD price: " # error); };
                case(#ok(_)) {};
            };
            switch(await* supply_usd_price_tracker.fetch_price()){
                case(#err(error)) { Debug.print("Failed to fetch supply USD price: " # error); };
                case(#ok(_)) {};
            };

            // 2. Liquidate unhealthy loans
            switch(await* collateral_price_tracker.fetch_price()){
                case(#err(error)) { Debug.print("Failed to update collateral price: " # error); };
                case(#ok(_)) {
                    switch(await* borrow_registry.check_all_positions_and_liquidate(time)){
                        case(#err(error)) { Debug.print("Failed to check positions and liquidate: " # error); };
                        case(#ok(_)) {};
                    };
                };
            };

            // Time might have advanced during async calls
            time := clock.get_time();

            // 3. Update foresights before unlocking, so the rewards are up-to-date
            foresight_updater.update_foresights(time);

            // 4. Unlock expired locks and process them
            let unlocked_ids = lock_scheduler.try_unlock(time);

            // 5. Process each unlocked position
            label unlock_supply for (position_id in Set.keys(unlocked_ids)) {

                let position = switch(Map.get(position_register.positions, Map.thash, position_id)) {
                    case(null) { 
                        Debug.print("Position " # debug_show(position_id) # " not found");
                        continue unlock_supply;
                    };
                    case(?#YES_NO(position)) { position; };
                };
                let { pool_id; } = position;

                let pool_type = switch(Map.get(pool_register.pools, Map.thash, pool_id)) {
                    case(null) { 
                        Debug.print("Pool " # debug_show(pool_id) # " not found");
                        continue unlock_supply;
                    };
                    case(?v) { v; };
                };

                pool_type_controller.unlock_position({ pool_type; position_id; });
                
                // Remove supply position using the position's foresight reward
                switch(redistribution_hub.remove_position({
                    id = position_id;
                    interest_amount = Int.abs(position.foresight.reward);
                    time;
                })){
                    case(#err(err)) { Debug.print("Failed to remove supply position for position " # debug_show(position_id) # ": " # err); };
                    case(#ok(_)) {};
                };
            };
            
            switch(await* withdrawal_queue.process_pending_withdrawals(time)){
                case(#err(error)) { Debug.print("Failed to process pending withdrawals: " # error); };
                case(#ok(_)) {};
            };

            // 6. Mint mining tokens
            switch(miner.mine(time)){
                case(#err(error)) { Debug.print("Failed to distribute mining rewards: " # error); };
                case(#ok(_)) {};
            };
        };

        public func claim_mining_rewards(account: Account) : async* ?Nat {
            let now = clock.get_time();
            await* miner.withdraw(account, now);
        };

        public func get_mining_trackers() : [(Account, MiningTracker)] {
            miner.get_trackers();
        };

        public func get_mining_tracker(account: Account) : ?MiningTracker {
            miner.get_tracker(account);
        };

        public func get_mining_total_allocated() : RollingTimeline<Nat> {
            miner.get_total_allocated();
        };

        public func get_mining_total_claimed() : RollingTimeline<Nat> {
            miner.get_total_claimed();
        };

        public func get_clock() : Clock.Clock {
            clock;
        };

        public func get_info() : ProtocolInfo {
            {
                current_time = clock.get_time();
                genesis_time;
            };
        };

        public func get_collateral_token_price_usd() : Float {
            collateral_usd_price_tracker.get_token_price_usd();
        };

        public func get_supply_token_price_usd() : Float {
            supply_usd_price_tracker.get_token_price_usd();
        };

        type ProcessedPositionInput = {
            position_id: Text;
            pool_type: PoolType;
        };

        func process_position_input(args: PutPositionArgs) : Result<ProcessedPositionInput, Text> {
            
            let { id; pool_id; amount; } = args;

            let position_id = IdFormatter.format(#Position(id));

            let pool_type = switch(Map.get(pool_register.pools, Map.thash, pool_id)){
                case(null) return #err("Pool not found: " # pool_id);
                case(?v) v;
            };

            switch(Map.get(position_register.positions, Map.thash, position_id)){
                case(?_) return #err("Position already exists: " # position_id);
                case(null) {};
            };

            if (amount < parameters.minimum_position_amount){
                return #err("Insufficient amount: " # debug_show(amount) # " (minimum: " # debug_show(parameters.minimum_position_amount) # ")");
            };

            #ok({
                position_id;
                pool_type;
            });
        };

        func perform_put_position({
            args: PutPositionArgs;
            timestamp: Nat;
            pool_type: PoolType;
            position_id: Text;
            tx_id: Nat;
            supply_index: Float;
        }): PutPositionResult {
            
            let from = { owner = args.caller; subaccount = args.from_subaccount };

            let put_position = pool_type_controller.put_position({
                pool_type;
                choice_type = args.choice_type;
                args = { args with position_id; tx_id; supply_index; timestamp; from };
            });

            // TODO: critical: need to process unlocked ids
            ignore lock_scheduler.try_unlock(timestamp);

            lock_scheduler.add(
                PositionUtils.unwrap_lock(put_position.new),
                IterUtils.map<PositionType, Lock>(
                    pool_type_controller.pool_positions(pool_type),
                    PositionUtils.unwrap_lock
                )
            );
            // Need to update the foresights after adding the new lock
            foresight_updater.update_foresights(timestamp);

            MapUtils.putInnerSet(position_register.by_account, MapUtils.acchash, from, Map.thash, position_id);

            #ok(SharedConversions.sharePutPositionSuccess(put_position));
        };

    };

};