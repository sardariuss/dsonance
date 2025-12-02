import Result          "mo:base/Result";
import Float           "mo:base/Float";

import Map             "mo:map/Map";

import Types           "../Types";
import LendingTypes    "Types";
import Indexer         "Indexer";
import WithdrawalQueue "WithdrawalQueue";
import SupplyAccount   "SupplyAccount";

module {

    type Account = Types.Account;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type Transfer = Types.Transfer;
    type TransferError = Types.TransferError;
    type TxIndex = Types.TxIndex;

    type SupplyInput             = LendingTypes.SupplyInput;
    type SupplyPosition          = LendingTypes.SupplyPosition;
    type Withdrawal              = LendingTypes.Withdrawal;
    type SupplyParameters        = LendingTypes.SupplyParameters;
    type AddSupplyPositionResult = LendingTypes.AddSupplyPositionResult;

    public type SupplyRegister = {
        supply_positions: Map.Map<Text, SupplyPosition>;
        var total_supplied: Float; // Total supplied (sum of all positions' supplied, no interests)
        var total_raw: Float; // Total raw supplied (principal)
        var index: Float; // Supply index at last update
    };

    // \brief This class allows to redistribute interests accrued by all positions.
    // The interests are added to a common pool and can be redistributed arbitrarily 
    // to each position via the interest_amount parameter of remove_position.
    // Note that the positions' index is meant to be used only in the frontend 
    // for displaying what the base APY is - it is not meant to be used for calculations
    // in any way.
    public class RedistributionHub({
        indexer: Indexer.Indexer;
        register: SupplyRegister;
        supply: SupplyAccount.SupplyAccount;
        parameters: SupplyParameters;
        withdrawal_queue: WithdrawalQueue.WithdrawalQueue;
    }){

        public func get_position({ id: Text }) : ?SupplyPosition {
            Map.get(register.supply_positions, Map.thash, id);
        };

        // ⚠️ This function is only for preview purposes, it does not perform the transfer.
        // It is intended to be used in a query for previewing the supply position.
        // No check are done to ensure that the supply cap is not reached.
        // It is required to do the add_raw_supplied to update the indexer in order to notify the
        // foresight updater which is an observer of the indexer.
        public func add_position_without_transfer(input: SupplyInput, time: Nat) : AddSupplyPositionResult {

            let tx_id = 0; // Tx set arbitrarily to 0, as no transfer is done

            add({ input; time; tx_id; });

            let supply_index = indexer.get_index_now(time).supply_index.value;

            #ok({ supply_index; tx_id; });
        };

        public func add_position(input: SupplyInput, time: Nat) : async* AddSupplyPositionResult {

            let { id; account; supplied; } = input;

            if (Map.has(register.supply_positions, Map.thash, id)){
                return #err("The map already has a position with the ID " # debug_show(id));
            };

            let lending_index = indexer.get_index_now(time);

            if (lending_index.utilization.raw_supplied + Float.fromInt(supplied) > Float.fromInt(parameters.supply_cap)){
                return #err("Cannot add position, the supply cap of " # debug_show(parameters.supply_cap) # " is reached");
            };

            let tx_id = switch(await* supply.pull({ from = account; amount = supplied; protocol_fees = null; })) {
                case(#err(err)) { return #err(err); };
                case(#ok(tx_index)) { tx_index; };
            };

            // TODO: small risk here that a user call add_position twice in parallel, two transfer succeed,
            // and only one position is set

            add({ input; time; tx_id; });

            #ok({ supply_index = lending_index.supply_index.value; tx_id; });
        };

        // Remove a position from the supply registry.
        // Watchout, the transfer is not done immediately, it is added to the withdrawal queue.
        public func remove_position({ id: Text; interest_amount: Nat; time: Nat; }) : Result<Nat, Text> {
            
            let position = switch(Map.get(register.supply_positions, Map.thash, id)){
                case(null) { return #err("The map does not have a position with the ID " # debug_show(id)); };
                case(?p) { p; };
            };

            ignore indexer.update(time);
            let total_interests = get_total_interests();

            // Make sure the amount is not greater than available supply interests
            if (Float.fromInt(interest_amount) > total_interests) {
                return #err("Interest amount " # debug_show(interest_amount) # " is greater than total interests " # debug_show(total_interests));
            };

            // Remove from supply positions
            remove({ pos = position; interest_amount; time; });

            let due = position.supplied + interest_amount;
            withdrawal_queue.add({ position; due; time; });

            #ok(due);
        };

        func add({ input: SupplyInput; time: Nat; tx_id: TxIndex; }) {
            let { id; supplied; } = input;
            
            // Add to total supplied
            register.total_supplied += Float.fromInt(supplied);

            // Update indexer and total raw
            ignore indexer.update(time);
            register.total_raw := indexer.scale_supply_up({ 
                principal = register.total_raw; 
                past_index = register.index; 
            });
            
            // Add new supplied amount
            register.total_raw += Float.fromInt(supplied);
            register.index := indexer.add_raw_supplied({ amount = supplied; time; });

            Map.set(register.supply_positions, Map.thash, id, { input with tx = tx_id });
        };

        func remove({ pos : SupplyPosition; interest_amount: Nat; time: Nat; }) {
            let { supplied } = pos;

            // Remove from total supplied
            register.total_supplied -= Float.fromInt(supplied);

            // Update indexer and total raw
            ignore indexer.update(time);
            register.total_raw := indexer.scale_supply_up({ principal = register.total_raw; past_index = register.index; });
            
            // Compute principal portion to remove
            let scaled_amount = supplied + interest_amount;
            let raw_amount = indexer.scale_supply_down({ scaled = Float.fromInt(scaled_amount); past_index = register.index; });

            // Remove raw amount from total raw and indexer
            register.total_raw -= raw_amount;
            register.index := indexer.remove_raw_supplied({ amount = raw_amount; time; });

            Map.delete(register.supply_positions, Map.thash, pos.id);
        };

        public type SupplyInfo = { 
            accrued_interests: Float;
            interests_rate: Float;
            timestamp: Nat;
        };

        public func get_supply_info(time: Nat) : SupplyInfo {
            let lending_index = indexer.get_index_now(time);
            let total_worth = get_total_worth();
            let accrued_interests = total_worth - register.total_supplied;
            { 
                accrued_interests;
                interests_rate = lending_index.supply_rate;
                timestamp = lending_index.timestamp;
            };
        };

        func get_total_worth() : Float {
            indexer.scale_supply_up({ principal = register.total_raw; past_index = register.index; });
        };

        func get_total_interests() : Float {
            let total_worth = get_total_worth();
            total_worth - register.total_supplied;
        };

    };

};