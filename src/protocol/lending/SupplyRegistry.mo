import Nat                "mo:base/Nat";
import Map                "mo:map/Map";
import Result             "mo:base/Result";
import Float              "mo:base/Float";
import Int                "mo:base/Int";
import Principal          "mo:base/Principal";

import Types              "../Types";
import Math               "../utils/Math";
import LendingTypes       "Types";
import Indexer            "Indexer";
import WithdrawalQueue    "WithdrawalQueue";
import UtilizationUpdater "UtilizationUpdater";
import SupplyAccount      "SupplyAccount";
import SupplyPositionManager "SupplyPositionManager";

module {

    type Account               = Types.Account;
    type TxIndex               = Types.TxIndex;
    type Result<Ok, Err>       = Result.Result<Ok, Err>;

    type SupplyPosition        = LendingTypes.SupplyPosition;
    type SupplyPositionTx      = LendingTypes.SupplyPositionTx;
    type SupplyParameters      = LendingTypes.SupplyParameters;
    type LendingIndex          = LendingTypes.LendingIndex;
    type SupplyInfo            = LendingTypes.SupplyInfo;
    type SupplyOperation       = LendingTypes.SupplyOperation;
    type SupplyOperationArgs   = LendingTypes.SupplyOperationArgs;

    type PreparedOperation = {
        to_transfer: Nat;
        finalize: (TxIndex) -> SupplyOperation;
    };

    public class SupplyRegistry({
        supply: SupplyAccount.SupplyAccount;
        indexer: Indexer.Indexer;
        withdrawal_queue: WithdrawalQueue.WithdrawalQueue;
        parameters: SupplyParameters;
        position_manager: SupplyPositionManager.SupplyPositionManager;
    }) {

        public func get_position({ account: Account; }) : ?SupplyPosition {
            position_manager.get_position({ account; });
        };

        public func get_positions() : Map.Iter<SupplyPosition> {
            position_manager.get_positions();
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
            position_manager.get_supply_info(time, account);
        };

        public func get_all_supply_info(time: Nat) : { positions: [SupplyInfo]; total_supplied: Float } {
            position_manager.get_all_supply_info(time);
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
            let update = position_manager.add_tx({ position; tx; });
            position_manager.set_position({ account; position = update; });
            let index = indexer.update(time);
            {
                info = position_manager.get_supply_info(time, account);
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

            let position = position_manager.get_position({ account; });
            let update = position_manager.add_supply({ position; account; index = index.supply_index; amount; });

            let finalize = func(tx: TxIndex) : SupplyOperation {
                ignore indexer.add_raw_supplied({ amount; time; });
                common_finalize({
                    account;
                    position = update;
                    tx = #SUPPLIED(tx);
                    time;
                });
            };

            #ok({ to_transfer = amount; finalize; });
        };

        func prepare_withdraw({
            account: Account;
            amount: Nat;
            max_slippage_amount: Nat;
            time: Nat;
        }) : Result<PreparedOperation, Text> {

            let position = switch(position_manager.get_position({ account; })){
                case(null) { return #err("No supply position found for account " # debug_show(account)); };
                case(?p) { p; };
            };

            ignore indexer.update(time).supply_index;

            let withdraw_result = position_manager.withdraw_supply({ position; amount; max_slippage_amount; });
            let { withdrawn; raw_withdrawn; remaining; } = switch(withdraw_result){
                case(#err(err)) { return #err(err); };
                case(#ok(p)) { p; };
            };

            // Follow a "round-up for debt, round-down for rewards" policy
            let withdrawn_nat = Int.abs(Math.floor_to_int(withdrawn));

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

            #ok({ to_transfer = withdrawn_nat; finalize; });
        };

    };

};
