import Nat "mo:base/Nat";
import Debug "mo:base/Debug";
import Result "mo:base/Result";
import Int "mo:base/Int";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Float "mo:base/Float";

import Map "mo:map/Map";
import Set "mo:map/Set";

import Types "../Types";
import LedgerFacade "../payement/LedgerFacade";
import LendingTypes "Types";
import Indexer "Indexer";

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
        ledger: LedgerFacade.LedgerFacade;
    }){

        var awaiting_transfer = false;

        public func get_position({ id: Text }) : ?SupplyPosition {
            Map.get(register.supply_positions, Map.thash, id);
        };

        public func add_position(input: SupplyInput) : async* Result<(), Text> {

            let { id; account; supplied; timestamp; } = input;

            if (Map.has(register.supply_positions, Map.thash, id)){
                return #err("The map already has a position with the ID " # debug_show(id));
            };

            let tx = switch(await* ledger.transfer_from({ from = account; amount = supplied; })) {
                case(#err(_)) { return #err("Transfer failed"); };
                case(#ok(tx_index)) { tx_index; };
            };

            // TODO: small risk here that a user call add_position twice in parallel, two transfer succeed,
            // and only position is set

            Map.set(register.supply_positions, Map.thash, id, { input with tx; });
            indexer.add_raw_supplied({ time = timestamp; amount = supplied; });
            
            register.supply_balance += supplied;

            #ok;
        };

        public func remove_position({ id: Text; due: Nat; time: Nat; }) : Result<(), Text> {
            
            let position = switch(Map.get(register.supply_positions, Map.thash, id)){
                case(null) { return #err("The map does not have a position with the ID " # debug_show(id)); };
                case(?p) { p; };
            };

            // Remove from supply positions
            Map.delete(register.supply_positions, Map.thash, id);
            indexer.remove_raw_supplied({ time; amount = position.supplied; });

            // Create a withdrawal
            let withdrawal : Withdrawal = { 
                id = position.id;
                account = position.account;
                supplied = position.supplied;
                due;
                var transferred = 0;
                var transfers = [];
            };
            
            Map.set(register.withdrawals, Map.thash, id, withdrawal);
            // Add to the queue only if there is an amount due
            if (due > 0) {
                Set.add(register.withdraw_queue, Set.thash, id);
            };

            #ok;
        };

        public func process_withdraw_queue({ available_liquidity: Nat; }) : async* Result<[Transfer], Text> {

            // Prevent re-entry
            if (awaiting_transfer){
                return #err("Withdraw queue is currently awaiting transfer, try again later");
            };

            let buffer_transferring = Buffer.Buffer<async* Transfer>(0);

            var available_for_transfer = available_liquidity;

            label queue_loop for (id in Set.keys(register.withdraw_queue)){

                let withdrawal = switch(Map.get(register.withdrawals, Map.thash, id)){
                    case(null) { 
                        Debug.print("Cannot process element from the withdraw queue: the map does not have a withdrawal with the ID " # debug_show(id));
                        continue queue_loop;
                    };
                    case(?w) { w; };
                };

                let diff : Int = withdrawal.due - withdrawal.transferred;
                if (diff <= 0) {
                    Debug.print("Logic error: supply position with transferred amount superior or equal to the amount due. Remove position from the queue.");
                    Set.delete(register.withdraw_queue, Set.thash, id);
                    continue queue_loop;
                };

                let amount = Nat.min(Int.abs(diff), available_for_transfer);
                buffer_transferring.add(transfer({ withdrawal; amount; }));
                available_for_transfer -= amount;

                // No need to continue
                if (available_for_transfer == 0){
                    break queue_loop;
                };
            };

            awaiting_transfer := true;
            var transfers = Buffer.Buffer<Transfer>(0);

            for (transferring in buffer_transferring.vals()){
                transfers.add(await* transferring);
            };

            awaiting_transfer := false;
            #ok(Buffer.toArray(transfers));
        };

        func transfer({ withdrawal: Withdrawal; amount: Nat; }) : async* Transfer {

            let transfer = await* ledger.transfer({ to = withdrawal.account; amount; });

            // Add the transfer
            withdrawal.transfers := Array.append(withdrawal.transfers, [transfer]);

            switch(transfer.result){
                case(#ok(_)){

                    withdrawal.transferred += amount;

                    // Delete from the queue if all due has been transferred
                    if (withdrawal.transferred >= withdrawal.due) {
                        Set.delete(register.withdraw_queue, Set.thash, withdrawal.id);
                    };

                    register.supply_balance -= amount;
                };
                case(#err(_)){

                    // Remove from the queue to avoid potentially blocking other transfers
                    Set.delete(register.withdraw_queue, Set.thash, withdrawal.id);
                };
            };

            transfer;
        };

    };

    // @todo: remove
//    func compute_raw_withdrawn(withdrawal: Withdrawal) : Float {
//        let ratio_removed = Float.fromInt(withdrawal.transferred) / Float.fromInt(withdrawal.due);
//        let raw_withdrawn = ratio_removed * Float.fromInt(withdrawal.supplied);
//        if (raw_withdrawn < 0.0){
//            Debug.trap("Logic error: supply removed shall never be negative");
//        };
//        raw_withdrawn;
//    };

};