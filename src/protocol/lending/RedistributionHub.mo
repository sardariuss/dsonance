import Result          "mo:base/Result";
import Float           "mo:base/Float";

import Map             "mo:map/Map";

import Types           "../Types";
import LendingTypes    "Types";
import Indexer         "Indexer";
import SupplyAccount   "SupplyAccount";
import RedistributionPositionManager "RedistributionPositionManager";

module {

    type Account = Types.Account;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type Transfer = Types.Transfer;
    type TransferError = Types.TransferError;
    type TxIndex = Types.TxIndex;

    type RedistributionInput              = LendingTypes.RedistributionInput;
    type RedistributionPosition           = LendingTypes.RedistributionPosition;
    type Withdrawal                       = LendingTypes.Withdrawal;
    type SupplyParameters                 = LendingTypes.SupplyParameters;
    type AddRedistributionPositionResult  = LendingTypes.AddRedistributionPositionResult;
    type RedistributionRegister           = LendingTypes.RedistributionRegister;

    public type SupplyInfo = {
        accrued_interests: Float;
        interests_rate: Float;
        timestamp: Nat;
    };

    // \brief This class allows to redistribute interests accrued by all positions.
    // The interests are added to a common pool and can be redistributed arbitrarily 
    // to each position via the interest_amount parameter of remove_position.
    // Note that the positions' index is meant to be used only in the frontend 
    // for displaying what the base APY is - it is not meant to be used for calculations
    // in any way.
    public class RedistributionHub({
        indexer: Indexer.Indexer;
        redistribution: RedistributionRegister;
        supply: SupplyAccount.SupplyAccount;
        parameters: SupplyParameters;
        supply_registry: {
            add_supply_without_pull: ({ account: Account; amount: Float; time: Nat; }) -> Result<(), Text>;
            remove_supply_without_transfer: ({ account: Account; amount: Nat; max_slippage_amount: Nat; time: Nat; }) -> Result<Float, Text>;
        };
    }){

        let position_manager = RedistributionPositionManager.RedistributionPositionManager({
            redistribution;
            indexer;
        });

        public func get_position({ id: Text }) : ?RedistributionPosition {
            position_manager.get_position({ id; });
        };

        // ⚠️ This function is only for preview purposes, it does not perform the transfer.
        // It is intended to be used in a query for previewing the supply position.
        // No check are done to ensure that the supply cap is not reached.
        // It is required to do the add_raw_supplied to update the indexer in order to notify the
        // foresight updater which is an observer of the indexer.
        public func add_position_without_transfer(input: RedistributionInput, time: Nat) : AddRedistributionPositionResult {

            let tx_id = 0; // Tx set arbitrarily to 0, as no transfer is done

            ignore indexer.add_raw_supplied({ amount = input.supplied; time; });
            let supply_index = position_manager.add_position({ input; tx_id; time; });

            #ok({ supply_index; tx_id; });
        };

        public func add_position(input: RedistributionInput, time: Nat) : async* AddRedistributionPositionResult {

            let { id; account; supplied; } = input;

            if (Map.has(redistribution.redistribution_positions, Map.thash, id)){
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

            // Add with wallet origin (updates indexer)
            ignore indexer.add_raw_supplied({ amount = supplied; time; });
            let supply_index = position_manager.add_position({ input; tx_id; time; });

            #ok({ supply_index; tx_id; });
        };

        // Add redistribution position from SupplyRegistry (no token transfer)
        // Takes funds from the user's SupplyPosition and moves them to RedistributionHub
        public func add_position_from_supply({
            input: RedistributionInput;
            max_slippage_amount: Nat;
            time: Nat;
        }) : AddRedistributionPositionResult {

            let { id; account; supplied; } = input;

            if (Map.has(redistribution.redistribution_positions, Map.thash, id)){
                return #err("The map already has a position with the ID " # debug_show(id));
            };

            // ⚠️ Do not check supply cap here, as funds are already in the system

            // Remove from SupplyRegistry (no transfer, just accounting)
            switch(supply_registry.remove_supply_without_transfer({
                account;
                amount = supplied;
                max_slippage_amount;
                time;
            })){
                case(#err(err)) { return #err("Failed to remove from supply position: " # err); };
                case(#ok(_)) {};
            };

            // Add to RedistributionHub (no indexer update, funds already in system)
            let supply_index = position_manager.add_position({ input; tx_id = 0; time; });

            #ok({ supply_index; tx_id = 0; });
        };

        // Remove a position from the redistribution registry.
        // The funds (supplied + interest) are added to the account's SupplyPosition in SupplyRegistry.
        public func remove_position({ id: Text; interest_amount: Nat; time: Nat; }) : Result<Nat, Text> {

            // Remove position using position_manager
            let { position; due; } = switch(position_manager.remove_position({ id; interest_amount; time; })){
                case(#err(err)) { return #err(err); };
                case(#ok(result)) { result; };
            };

            // Add to the account's SupplyPosition (no transfer, just accounting)
            switch(supply_registry.add_supply_without_pull({
                account = position.account;
                amount = Float.fromInt(due);
                time;
            })){
                case(#err(err)) { return #err("Failed to add to supply position: " # err); };
                case(#ok(_)) {};
            };

            #ok(due);
        };

        public func get_supply_info(time: Nat) : SupplyInfo {
            position_manager.get_supply_info(time);
        };

    };

};