import Debug           "mo:base/Debug";
import Result          "mo:base/Result";
import Int             "mo:base/Int";
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
    type SupplyRegister          = LendingTypes.SupplyRegister;
    type SupplyParameters        = LendingTypes.SupplyParameters;
    type AddSupplyPositionResult = LendingTypes.AddSupplyPositionResult;

    // @todo: need functions to retry if transfer failed.
    // @todo: need queries to retrieve the transfers and withdrawals (union of the two maps)
    // @todo: function to delete withdrawals that are too old
    public class SupplyRegistry({
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

            let { id; supplied; } = input;

            let tx = 0; // Tx set arbitrarily to 0, as no transfer is done

            Map.set(register.supply_positions, Map.thash, id, { input with tx; });
            indexer.add_raw_supplied({ amount = supplied; time; });

            let supply_index = indexer.get_index(time).supply_index.value;

            #ok({ supply_index; tx_id = tx; });
        };

        public func add_position(input: SupplyInput, time: Nat) : async* AddSupplyPositionResult {

            let { id; account; supplied; } = input;

            if (Map.has(register.supply_positions, Map.thash, id)){
                return #err("The map already has a position with the ID " # debug_show(id));
            };

            let lending_index = indexer.get_index(time);

            if (lending_index.utilization.raw_supplied + Float.fromInt(supplied) > Float.fromInt(parameters.supply_cap)){
                return #err("Cannot add position, the supply cap of " # debug_show(parameters.supply_cap) # " is reached");
            };

            let tx = switch(await* supply.pull({ from = account; amount = supplied; protocol_fees = null; })) {
                case(#err(err)) { return #err(err); };
                case(#ok(tx_index)) { tx_index; };
            };

            // TODO: small risk here that a user call add_position twice in parallel, two transfer succeed,
            // and only one position is set

            Map.set(register.supply_positions, Map.thash, id, { input with tx; });
            indexer.add_raw_supplied({ amount = supplied; time; });

            #ok({ supply_index = lending_index.supply_index.value; tx_id = tx; });
        };

        // Remove a position from the supply registry.
        // Watchout, the transfer is not done immediately, it is added to the withdrawal queue.
        public func remove_position({ id: Text; interest_amount: Nat; time: Nat; }) : Result<Nat, Text> {
            
            let position = switch(Map.get(register.supply_positions, Map.thash, id)){
                case(null) { return #err("The map does not have a position with the ID " # debug_show(id)); };
                case(?p) { p; };
            };

            // Remove from supply positions
            Map.delete(register.supply_positions, Map.thash, id);

            // Take the specified amount from supply interests
            switch(indexer.take_supply_interests({ amount = Float.fromInt(interest_amount); time; })){
                case(#err(err)) { return #err(err); };
                case(#ok(_)) {};
            };
            let due = do {
                let sum : Int = position.supplied + interest_amount;
                if (sum < 0) {
                    Debug.trap("Logic error: supply + interest amount shall never be negative");
                };
                Int.abs(sum);
            };

            withdrawal_queue.add({ position; due; time; });

            #ok(due);
        };

    };

};