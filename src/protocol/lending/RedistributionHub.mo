import Result          "mo:base/Result";
import Float           "mo:base/Float";

import Map             "mo:map/Map";

import Types           "../Types";
import LendingTypes    "Types";
import Indexer         "Indexer";
import SupplyAccount   "SupplyAccount";

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

    type SupplyInfo = { 
        accrued_interests: Float;
        interests_rate: Float;
        timestamp: Nat;
    };

    type AmountOrigin = {
        #FROM_SUPPLY_ACCOUNT;
        #FROM_USER_WALLET;
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

        public func get_position({ id: Text }) : ?RedistributionPosition {
            Map.get(redistribution.redistribution_positions, Map.thash, id);
        };

        // ⚠️ This function is only for preview purposes, it does not perform the transfer.
        // It is intended to be used in a query for previewing the supply position.
        // No check are done to ensure that the supply cap is not reached.
        // It is required to do the add_raw_supplied to update the indexer in order to notify the
        // foresight updater which is an observer of the indexer.
        public func add_position_without_transfer(input: RedistributionInput, time: Nat) : AddRedistributionPositionResult {

            let tx_id = 0; // Tx set arbitrarily to 0, as no transfer is done

            add({ input; time; tx_id; origin = #FROM_USER_WALLET; });

            let supply_index = indexer.get_index_now(time).supply_index.value;

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

            add({ input; time; tx_id; origin = #FROM_USER_WALLET; });

            #ok({ supply_index = lending_index.supply_index.value; tx_id; });
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

            let lending_index = indexer.get_index_now(time);

            if (lending_index.utilization.raw_supplied + Float.fromInt(supplied) > Float.fromInt(parameters.supply_cap)){
                return #err("Cannot add position, the supply cap of " # debug_show(parameters.supply_cap) # " is reached");
            };

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

            // Add to RedistributionHub without calling indexer.add_raw_supplied
            add({ input; time; tx_id = 0; origin = #FROM_SUPPLY_ACCOUNT; });

            #ok({ supply_index = lending_index.supply_index.value; tx_id = 0; });
        };

        // Remove a position from the redistribution registry.
        // The funds (supplied + interest) are added to the account's SupplyPosition in SupplyRegistry.
        public func remove_position({ id: Text; interest_amount: Nat; time: Nat; }) : Result<Nat, Text> {

            let position = switch(Map.get(redistribution.redistribution_positions, Map.thash, id)){
                case(null) { return #err("The map does not have a position with the ID " # debug_show(id)); };
                case(?p) { p; };
            };

            ignore indexer.update(time);
            let total_interests = get_total_interests();

            // Make sure the amount is not greater than available supply interests
            if (Float.fromInt(interest_amount) > total_interests) {
                return #err("Interest amount " # debug_show(interest_amount) # " is greater than total interests " # debug_show(total_interests));
            };

            let due = position.supplied + interest_amount;

            // Add to the account's SupplyPosition (no transfer, just accounting)
            switch(supply_registry.add_supply_without_pull({
                account = position.account;
                amount = Float.fromInt(due);
                time;
            })){
                case(#err(err)) { return #err("Failed to add to supply position: " # err); };
                case(#ok(_)) {};
            };

            // Remove from redistribution positions (does NOT call indexer.remove_raw_supplied)
            remove({ pos = position; interest_amount; time; });

            #ok(due);
        };

        func add({ input: RedistributionInput; time: Nat; tx_id: TxIndex; origin: AmountOrigin; }) {
            let { id; supplied; } = input;

            // Update indexer and total raw
            let supply_index = switch(origin){
                case(#FROM_SUPPLY_ACCOUNT) {
                    // Funds are already in the system, just update the index
                    indexer.get_index_now(time).supply_index.value;
                };
                case(#FROM_USER_WALLET) {
                    // New funds coming from user, need to be added
                    indexer.add_raw_supplied({ amount = supplied; time; });
                };
            };
            
            // Update total raw to current index
            redistribution.total_raw := indexer.scale_supply_up({
                principal = redistribution.total_raw;
                past_index = redistribution.index;
            });
            redistribution.index := supply_index;

            // Add to total raw and total supplied
            redistribution.total_supplied += Float.fromInt(supplied);
            redistribution.total_raw += Float.fromInt(supplied);
            
            Map.set(redistribution.redistribution_positions, Map.thash, id, { input with tx = tx_id });
        };

        // Remove position without calling indexer.remove_raw_supplied
        // Used when funds stay in the system (moved to SupplyRegistry)
        func remove({ pos : RedistributionPosition; interest_amount: Nat; time: Nat; }) {
            let { supplied } = pos;

            // Update total raw to current value
            let supply_index = indexer.update(time).supply_index.value;
            redistribution.total_raw := indexer.scale_supply_up({ 
                principal = redistribution.total_raw;
                past_index = redistribution.index; 
            });
            redistribution.index := supply_index;

            // Remove supplied + interest from total raw
            redistribution.total_raw -= Float.fromInt(supplied);
            redistribution.total_raw -= Float.fromInt(interest_amount);

            // Remove supplied from total supplied
            redistribution.total_supplied -= Float.fromInt(supplied);

            Map.delete(redistribution.redistribution_positions, Map.thash, pos.id);
        };

        public func get_supply_info(time: Nat) : SupplyInfo {
            let lending_index = indexer.get_index_now(time);
            let total_worth = get_total_worth();
            let accrued_interests = total_worth - redistribution.total_supplied;
            { 
                accrued_interests;
                interests_rate = lending_index.supply_rate;
                timestamp = lending_index.timestamp;
            };
        };

        func get_total_worth() : Float {
            indexer.scale_supply_up({ principal = redistribution.total_raw; past_index = redistribution.index; });
        };

        func get_total_interests() : Float {
            let total_worth = get_total_worth();
            total_worth - redistribution.total_supplied;
        };

    };

};