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

module {

    type Account = Types.Account;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type Transfer = Types.Transfer;
    type TransferError = Types.TransferError;

    public type SupplyInput = {
        id: Text;
        account: Account;
        supplied: Nat;
    };

    public type SupplyPosition = SupplyInput and {
        withdrawned: ?Withdrawal;
    };

    public type SupplyState = {
        #LOCKED;
        #UNLOCKED: Withdrawal;
    };

    public type Withdrawal = {
        id: Text;
        account: Account;
        supplied: Nat;
        due: Nat;
        var transferred: Nat;
        var tx_errors: [TransferError]; // @todo: need to limit the number of errors
    };

    public type SupplyRegister = {
        var total_supplied: Nat;
        ledger: LedgerFacade.LedgerFacade;
        positions: Map.Map<Text, SupplyPosition>;
        withdrawals: Map.Map<Text, Withdrawal>;
        withdraw_queue: Set.Set<Text>;
    };

    // @todo: need functions to retry if transfer failed and queries.
    public class SupplyRegistry(register: SupplyRegister){

        var awaiting_transfer = false;

        public func get_total_supplied() : Nat {
            register.total_supplied;
        };

        public func get_position({ id: Text }) : ?SupplyPosition {
            Map.get(register.positions, Map.thash, id);
        };

        public func add_position(input: SupplyInput) : async* Result<(), Text> {

            let { id; account; supplied; } = input;

            if (Map.has(register.positions, Map.thash, id)){
                Debug.trap("The map already has a position with the ID " # debug_show(id));
            };

            switch(await* register.ledger.transfer_from({ from = account; amount = supplied; })){
                case(#err(_)) { return #err("Transfer failed"); };
                case(#ok(_)) {};
            };

            // TODO: small risk here that a user call add_position twice in parallel, two transfer succeed,
            // and only position is set
        
            Map.set(register.positions, Map.thash, id, { input with withdrawned = null; });
            register.total_supplied += supplied;

            #ok;
        };

        public func withdraw_position({ id: Text; due: Nat; }){
            
            let position = switch(Map.get(register.positions, Map.thash, id)){
                case(null) { Debug.trap("The map does not have a position with the ID " # debug_show(id)); };
                case(?p) { p; };
            };

            let withdrawal : Withdrawal = { 
                id = position.id;
                account = position.account;
                supplied = position.supplied;
                due;
                var transferred = 0;
                var tx_errors = [];
            };

            Map.set(register.withdrawals, Map.thash, id, withdrawal);

            // Add to the queue only if there is an amount due
            if (due > 0) {
                Set.add(register.withdraw_queue, Set.thash, id);
            };
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

            let transfer = await* register.ledger.transfer({ to = withdrawal.account; amount; });

            switch(transfer.result){
                case(#ok(_)){

                    let before_removed = compute_supplied_removed(withdrawal);
                    withdrawal.transferred += amount;
                    let after_removed = compute_supplied_removed(withdrawal);
                    
                    register.total_supplied -= (after_removed - before_removed); // To avoid cumulative drift

                    // Delete from the queue if all due has been transferred
                    if (withdrawal.transferred >= withdrawal.due) {
                        Set.delete(register.withdraw_queue, Set.thash, withdrawal.id);
                    };
                };
                case(#err(err)){

                    // Add the error
                    withdrawal.tx_errors := Array.append(withdrawal.tx_errors, [err]);

                    // Remove from the queue to avoid potentially blocking other transfers
                    Set.delete(register.withdraw_queue, Set.thash, withdrawal.id);
                };
            };

            transfer;
        };

        func compute_supplied_removed(withdrawal: Withdrawal) : Nat {
            let ratio_removed = Float.fromInt(withdrawal.transferred) / Float.fromInt(withdrawal.due);
            let supplied_removed = Float.toInt(ratio_removed * Float.fromInt(withdrawal.supplied));
            if (supplied_removed < 0){
                Debug.trap("Logic error: supply removed shall never be negative");
            };
            Int.abs(supplied_removed);
        };

    };

};