import Nat                "mo:base/Nat";
import Map                "mo:map/Map";
import Result             "mo:base/Result";
import Float              "mo:base/Float";
import Int                "mo:base/Int";
import Principal          "mo:base/Principal";
import Array              "mo:base/Array";

import Types              "../Types";
import MapUtils           "../utils/Map";
import Math               "../utils/Math";
import LendingTypes       "Types";
import Indexer            "Indexer";
import WithdrawalQueue    "WithdrawalQueue";
import UtilizationUpdater "UtilizationUpdater";
import SupplyAccount      "SupplyAccount";

module {

    type Account               = Types.Account;
    type TxIndex               = Types.TxIndex;
    type Result<Ok, Err>       = Result.Result<Ok, Err>;

    type SupplyPosition        = LendingTypes.SupplyPosition;
    type SupplyPositionTx      = LendingTypes.SupplyPositionTx;
    type SupplyRegister        = LendingTypes.SupplyRegister;
    type SupplyParameters      = LendingTypes.SupplyParameters;
    type LendingIndex          = LendingTypes.LendingIndex;
    type SupplyInfo            = LendingTypes.SupplyInfo;
    type SupplyOperation       = LendingTypes.SupplyOperation;
    type SupplyOperationArgs   = LendingTypes.SupplyOperationArgs;

    type PreparedOperation = {
        to_transfer: Nat;
        protocol_fees: ?Float;
        finalize: (TxIndex) -> SupplyOperation;
    };

    public class SupplyRegistry({
        register: SupplyRegister;
        supply: SupplyAccount.SupplyAccount;
        indexer: Indexer.Indexer;
        withdrawal_queue: WithdrawalQueue.WithdrawalQueue;
        parameters: SupplyParameters;
    }) {

        public func get_position({ account: Account; }) : ?SupplyPosition {
            Map.get(register.supply_positions, MapUtils.acchash, account);
        };

        public func get_positions() : Map.Iter<SupplyPosition> {
            Map.vals(register.supply_positions);
        };

        public func run_operation(time: Nat, args: SupplyOperationArgs) : async* Result<SupplyOperation, Text> {

            let { account; } = args;

            if (Principal.isAnonymous(account.owner)) {
                return #err("Anonymous account cannot perform supply operations");
            };

            let { to_transfer; finalize; } = switch(prepare_operation(time, args)){
                case(#err(err)) { return #err(err); };
                case(#ok(p)) { p; };
            };

            let transfer = switch(args.kind){
                case(#SUPPLY) {  await* supply.pull({ from = account; amount = to_transfer; protocol_fees = null; }); };
                case(#WITHDRAW(_)) {  await* supply.transfer({ to = account; amount = to_transfer; }); };
            };

            let tx = switch(transfer){
                case(#err(err)) { return #err("Failed to perform transfer: " # debug_show(err)); };
                case(#ok(tx_index)) { tx_index; };
            };

            let to_return = finalize(tx);

            switch(args.kind){
                case(#WITHDRAW(_)) {
                    // Once a position is withdrawn, it might allow to process pending withdrawals
                    ignore await* withdrawal_queue.process_pending_withdrawals(time);
                };
                case(_) {}; // No need to process pending withdrawals for supply
            };

            #ok(to_return);
        };

        public func run_operation_for_free(time: Nat, args: SupplyOperationArgs) : Result<SupplyOperation, Text> {

            let { finalize; } = switch(prepare_operation(time, args)){
                case(#err(err)) { return #err(err); };
                case(#ok(p)) { p; };
            };

            #ok(finalize(0)); // TxIndex is arbitrarily set to 0 for preview
        };

        public func get_supply_info(time: Nat, account: Account) : SupplyInfo {

            let index = indexer.get_index_now(time).supply_index;

            switch (Map.get(register.supply_positions, MapUtils.acchash, account)){
                case(null) {
                    {
                        account;
                        supplied = 0.0;
                        accrued_amount = 0.0;
                        supply_index = index;
                    };
                };
                case(?position) {
                    to_supply_info({ position; index; });
                };
            };
        };

        public func get_all_supply_info(time: Nat) : { positions: [SupplyInfo]; total_supplied: Float } {

            let index = indexer.get_index_now(time).supply_index;

            let positions : [SupplyInfo] = Map.toArrayMap<Account, SupplyPosition, SupplyInfo>(register.supply_positions, func (account: Account, position: SupplyPosition) : ?SupplyInfo {
                ?to_supply_info({ position; index; });
            });

            var total_supplied : Float = 0.0;
            for (info in positions.vals()) {
                total_supplied += info.accrued_amount;
            };

            {
                positions;
                total_supplied;
            };
        };

        func prepare_operation(time: Nat, args: SupplyOperationArgs) : Result<PreparedOperation, Text> {

            let { amount; account; } = args;
            switch(args.kind){
                case(#SUPPLY) { prepare_supply({ time; amount; account; }) };
                case(#WITHDRAW({max_slippage_amount})) { prepare_withdraw({ time; amount; account; max_slippage_amount; }) };
            };
        };

        func common_finalize({
            account: Account;
            position: SupplyPosition;
            tx: SupplyPositionTx;
            time: Nat;
        }) : SupplyOperation {
            // Add the transaction to the position
            let update = add_tx({ position; tx; });
            Map.set(register.supply_positions, MapUtils.acchash, account, update);
            let index = indexer.update(time);
            {
                info = to_supply_info({ position = update; index = index.supply_index; });
                index;
            };
        };

        func prepare_supply({
            account: Account;
            amount: Nat;
            time: Nat;
        }) : Result<PreparedOperation, Text> {

            let index = indexer.update(time);

            // Check supply cap constraint
            let utilization = switch(UtilizationUpdater.add_raw_supplied(index.utilization, amount)){
                case(u) { u; };
            };

            if (utilization.raw_supplied > Float.fromInt(parameters.supply_cap)){
                return #err("Supply cap of " # debug_show(parameters.supply_cap) # " exceeded with current utilization " # debug_show(utilization));
            };

            let position = Map.get(register.supply_positions, MapUtils.acchash, account);
            let update = add_supply({ position; account; index = index.supply_index; amount; });

            let finalize = func(tx: TxIndex) : SupplyOperation {
                ignore indexer.add_raw_supplied({ amount; time; });
                common_finalize({
                    account;
                    position = update;
                    tx = #SUPPLIED(tx);
                    time;
                });
            };

            #ok({ to_transfer = amount; protocol_fees = null; finalize; });
        };

        func prepare_withdraw({
            account: Account;
            amount: Nat;
            max_slippage_amount: Nat;
            time: Nat;
        }) : Result<PreparedOperation, Text> {

            let position = switch(Map.get(register.supply_positions, MapUtils.acchash, account)){
                case(null) { return #err("No supply position found for account " # debug_show(account)); };
                case(?p) { p; };
            };

            ignore indexer.update(time).supply_index;

            let withdraw_result = withdraw_supply({ position; amount; max_slippage_amount; });
            let { withdrawn; raw_withdrawn; remaining; from_interests; } = switch(withdraw_result){
                case(#err(err)) { return #err(err); };
                case(#ok(p)) { p; };
            };

            // Follow a "round-up for debt, round-down for rewards" policy
            let withdrawn_nat = Int.abs(Math.floor_to_int(withdrawn));
            let floor_diff = withdrawn - Float.floor(withdrawn);

            // Consider the rounding difference as protocol fees
            let protocol_fees = ?(indexer.get_parameters().lending_fee_ratio * from_interests + floor_diff);

            let update = { position with raw_amount = remaining; };

            let finalize = func(tx: TxIndex) : SupplyOperation {
                ignore indexer.remove_raw_supplied({ amount = raw_withdrawn; time; });
                common_finalize({
                    account;
                    position = update;
                    tx = #WITHDRAWN(tx);
                    time;
                });
            };

            #ok({ to_transfer = withdrawn_nat; protocol_fees; finalize; });
        };

        func add_supply({
            position: ?SupplyPosition;
            account: Account;
            index: LendingTypes.Index;
            amount: Nat;
        }) : SupplyPosition {
            switch(position){
                case(null) {
                    // Create new position
                    {
                        account;
                        tx = [];
                        raw_amount = Float.fromInt(amount);
                        index = index.value;
                    };
                };
                case(?p) {
                    // Scale up existing position to current index
                    let scaled_up = indexer.scale_supply_up({
                        principal = p.raw_amount;
                        past_index = p.index;
                    });
                    // Add new amount
                    let new_raw = scaled_up + Float.fromInt(amount);
                    {
                        p with
                        raw_amount = new_raw;
                        index = index.value;
                    };
                };
            };
        };

        func withdraw_supply({
            position: SupplyPosition;
            amount: Nat;
            max_slippage_amount: Nat;
        }) : Result<{
            withdrawn: Float;
            raw_withdrawn: Float;
            remaining: Float;
            from_interests: Float;
        }, Text> {

            // Scale up to current value
            let current_value = indexer.scale_supply_up({
                principal = position.raw_amount;
                past_index = position.index;
            });

            let requested = Float.fromInt(amount);

            if (requested > current_value + Float.fromInt(max_slippage_amount)) {
                return #err("Requested withdrawal " # debug_show(requested) # " exceeds available balance " # debug_show(current_value) # " plus slippage tolerance " # debug_show(max_slippage_amount));
            };

            // If requested amount + slippage is close to the full balance, withdraw everything to avoid tiny leftovers
            var withdrawn = requested;
            if (Float.fromInt(amount + max_slippage_amount) >= current_value) {
                withdrawn := current_value;
            };

            // Calculate raw amount to remove
            let raw_withdrawn = indexer.scale_supply_down({
                scaled = withdrawn;
                past_index = position.index;
            });

            let remaining = position.raw_amount - raw_withdrawn;

            if (remaining < 0.0) {
                return #err("Remaining raw amount would be negative: " # debug_show(remaining));
            };

            // Calculate interest portion
            let from_interests = Float.max(0.0, withdrawn - position.raw_amount);

            #ok({
                withdrawn;
                raw_withdrawn;
                remaining;
                from_interests;
            });
        };

        func to_supply_info({
            position: SupplyPosition;
            index: LendingTypes.Index;
        }) : SupplyInfo {
            let accrued_amount = indexer.scale_supply_up({
                principal = position.raw_amount;
                past_index = position.index;
            });

            {
                account = position.account;
                supplied = position.raw_amount;
                accrued_amount;
                supply_index = index;
            };
        };

        func add_tx({
            position: SupplyPosition;
            tx: SupplyPositionTx;
        }) : SupplyPosition {
            let new_tx = Array.append(position.tx, [tx]);
            { position with tx = new_tx; };
        };

    };

};
