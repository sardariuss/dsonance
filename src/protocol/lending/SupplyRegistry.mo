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

    type SupplyInput    = LendingTypes.SupplyInput;
    type SupplyPosition = LendingTypes.SupplyPosition;
    type Withdrawal     = LendingTypes.Withdrawal;
    type SupplyRegister = LendingTypes.SupplyRegister;

    // @todo: need functions to retry if transfer failed.
    // @todo: need queries to retrieve the transfers and withdrawals (union of the two maps)
    // @todo: function to delete withdrawals that are too old
    public class SupplyRegistry({
        indexer: Indexer.Indexer;
        register: SupplyRegister;
        supply: SupplyAccount.SupplyAccount;
        withdrawal_queue: WithdrawalQueue.WithdrawalQueue;
    }){

        public func get_position({ id: Text }) : ?SupplyPosition {
            Map.get(register.supply_positions, Map.thash, id);
        };

        public func add_position(input: SupplyInput) : async* Result<Nat, Text> {

            let { id; account; supplied; } = input;

            if (Map.has(register.supply_positions, Map.thash, id)){
                return #err("The map already has a position with the ID " # debug_show(id));
            };

            let tx = switch(await* supply.pull({ from = account; amount = supplied; })) {
                case(#err(_)) { return #err("Transfer failed"); };
                case(#ok(tx_index)) { tx_index; };
            };

            // TODO: small risk here that a user call add_position twice in parallel, two transfer succeed,
            // and only one position is set

            Map.set(register.supply_positions, Map.thash, id, { input with tx; });
            indexer.add_raw_supplied({ amount = supplied; });

            #ok(tx);
        };

        // Remove a position from the supply registry.
        // Watchout, the transfer is not done immediately, it is added to the withdrawal queue.
        public func remove_position({ id: Text; share: Float; }) : Result<Nat, Text> {
            
            let position = switch(Map.get(register.supply_positions, Map.thash, id)){
                case(null) { return #err("The map does not have a position with the ID " # debug_show(id)); };
                case(?p) { p; };
            };

            // Remove from supply positions
            Map.delete(register.supply_positions, Map.thash, id);

            // Compute the amount due
            let interest_amount = switch(indexer.take_supply_interests({ share; minimum = -position.supplied; })){
                case(#err(err)) { return #err(err); };
                case(#ok(amount)) { amount; };
            };
            let due = do {
                let sum : Int = position.supplied + interest_amount;
                if (sum < 0) {
                    Debug.trap("Logic error: supply + interest amount shall never be negative");
                };
                Int.abs(sum);
            };

            withdrawal_queue.add({ position; due; });

            #ok(due);
        };

    };

};