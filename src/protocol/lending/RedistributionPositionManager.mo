import Result          "mo:base/Result";
import Float           "mo:base/Float";
import Map             "mo:map/Map";

import Types           "../Types";
import LendingTypes    "Types";
import Indexer         "Indexer";

module {

    type Account = Types.Account;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type TxIndex = Types.TxIndex;

    type RedistributionInput    = LendingTypes.RedistributionInput;
    type RedistributionPosition = LendingTypes.RedistributionPosition;
    type RedistributionRegister = LendingTypes.RedistributionRegister;

    public type SupplyInfo = {
        accrued_interests: Float;
        interests_rate: Float;
        timestamp: Nat;
    };

    // Pure accounting manager for redistribution positions
    // No token transfers, no indexer updates (raw_supplied)
    // Just position management with index scaling
    public class RedistributionPositionManager({
        redistribution: RedistributionRegister;
        indexer: Indexer.Indexer;
    }) {

        public func get_position({ id: Text }) : ?RedistributionPosition {
            Map.get(redistribution.redistribution_positions, Map.thash, id);
        };

        // Add a redistribution position
        // Returns the supply_index for the position
        public func add_position({
            input: RedistributionInput;
            tx_id: TxIndex;
            time: Nat;
        }) : Float {
            let { id; supplied; } = input;

            // Update total raw to current index
            let supply_index = indexer.update(time).supply_index.value;
            redistribution.total_raw := indexer.scale_supply_up({
                principal = redistribution.total_raw;
                past_index = redistribution.index;
            });
            redistribution.index := supply_index;

            // Add to total raw and total supplied
            redistribution.total_supplied += Float.fromInt(supplied);
            redistribution.total_raw += Float.fromInt(supplied);

            Map.set(redistribution.redistribution_positions, Map.thash, id, { input with tx = tx_id });

            supply_index;
        };

        // Remove a redistribution position
        // Returns the total amount (supplied + interest)
        public func remove_position({
            id: Text;
            interest_amount: Nat;
            time: Nat;
        }) : Result<{ position: RedistributionPosition; due: Nat; }, Text> {

            let position = switch(Map.get(redistribution.redistribution_positions, Map.thash, id)){
                case(null) { return #err("The map does not have a position with the ID " # debug_show(id)); };
                case(?p) { p; };
            };

            // Update index to have accurate worth calculation
            ignore indexer.update(time);
            let total_interests = get_total_interests();

            // Make sure the amount is not greater than available supply interests
            if (Float.fromInt(interest_amount) > total_interests) {
                return #err("Interest amount " # debug_show(interest_amount) # " is greater than total interests " # debug_show(total_interests));
            };

            let { supplied } = position;

            // Update total raw to current value
            let supply_index = indexer.update(time).supply_index.value;
            redistribution.total_raw := indexer.scale_supply_up({
                principal = redistribution.total_raw;
                past_index = redistribution.index;
            });
            redistribution.index := supply_index;

            let due = supplied + interest_amount;

            // Remove due from total raw
            redistribution.total_raw -= Float.fromInt(due);

            // Remove supplied from total supplied
            redistribution.total_supplied -= Float.fromInt(supplied);

            Map.delete(redistribution.redistribution_positions, Map.thash, position.id);
            
            #ok({ position; due; });
        };

        public func get_supply_info(time: Nat) : SupplyInfo {
            // Update index to have accurate worth calculation
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
