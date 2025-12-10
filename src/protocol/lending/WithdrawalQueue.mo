import Nat           "mo:base/Nat";
import Debug         "mo:base/Debug";
import Result        "mo:base/Result";
import Int           "mo:base/Int";
import Buffer        "mo:base/Buffer";
import Array         "mo:base/Array";
import Float         "mo:base/Float";

import Map           "mo:map/Map";
import Set           "mo:map/Set";

import Types         "../Types";
import SupplyAccount "SupplyAccount";
import LendingTypes  "Types";
import Indexer       "Indexer";

module {

    type Result<Ok, Err>    = Result.Result<Ok, Err>;
    type TransferResult     = Types.TransferResult;

    type RedistributionPosition = LendingTypes.RedistributionPosition;
    type Withdrawal             = LendingTypes.Withdrawal;
    type WithdrawalRegister     = LendingTypes.WithdrawalRegister;

    // @todo: need functions to retry if transfer failed.
    // @todo: need queries to retrieve the transfers and withdrawals (union of the two maps)
    // @todo: function to delete withdrawals that are too old
    public class WithdrawalQueue({
        indexer: Indexer.Indexer;
        register: WithdrawalRegister;
        supply: SupplyAccount.SupplyAccount;
    }){

        var awaiting_transfer = false;

        public func add({ position: RedistributionPosition; due: Nat; time: Nat; }) {

            let { id; account; supplied; } = position;

            // Create a withdrawal
            let withdrawal : Withdrawal = { 
                id;
                account;
                supplied;
                due;
                var transferred = 0;
                var transfers = [];
            };
            Map.set(register.withdrawals, Map.thash, id, withdrawal);

            if (due > 0) {
                // If there is an amount due, add to the queue, the amount will be
                // subtracted from the raw supply once the transfer is done.
                Set.add(register.withdraw_queue, Set.thash, id);
            } else {
                // If not, no transfer to be done, so we can remove the supplied amount right away!
                ignore indexer.remove_raw_supplied({ amount = Float.fromInt(supplied); time; });
            };
        };

        public func process_pending_withdrawals(time: Nat) : async* Result<[TransferResult], Text> {

            // Prevent re-entry
            if (awaiting_transfer){
                return #err("Withdraw queue is currently awaiting transfer, try again later");
            };

            var available_for_transfer = await* supply.get_available_liquidities();

            // Compute the amount available for transfer
            if (available_for_transfer <= 0){
                return #err("No supply available to transfer withdrawals");
            };

            // Initialize a buffer to hold the transfers
            let buffer_transferring = Buffer.Buffer<async* TransferResult>(0);

            // Process the queue
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
                buffer_transferring.add(transfer({ withdrawal; amount; time; }));
                available_for_transfer -= amount;

                // No need to continue
                if (available_for_transfer == 0){
                    break queue_loop;
                };
            };

            awaiting_transfer := true;
            var transfers = Buffer.Buffer<TransferResult>(0);

            for (transferring in buffer_transferring.vals()){
                transfers.add(await* transferring);
            };

            awaiting_transfer := false;
            #ok(Buffer.toArray(transfers));
        };

        func transfer({ withdrawal: Withdrawal; amount: Nat; time: Nat; }) : async* TransferResult {

            let transfer = await* supply.transfer({ to = withdrawal.account; amount; });

            // Add the transfer
            withdrawal.transfers := Array.append(withdrawal.transfers, [transfer]);

            switch(transfer){
                case(#ok(_)){

                    let prev_raw_withdrawn = compute_raw_withdrawn(withdrawal);
                    withdrawal.transferred += amount;
                    let new_raw_withdrawn = compute_raw_withdrawn(withdrawal);

                    // Remove the amount from the raw supply
                    ignore indexer.remove_raw_supplied({ amount = new_raw_withdrawn - prev_raw_withdrawn; time; });

                    // Delete from the queue if all due has been transferred
                    if (withdrawal.transferred >= withdrawal.due) {
                        Set.delete(register.withdraw_queue, Set.thash, withdrawal.id);
                    };
                };
                case(#err(_)){

                    // Remove from the queue to avoid potentially blocking other transfers
                    Set.delete(register.withdraw_queue, Set.thash, withdrawal.id);
                };
            };

            transfer;
        };

    };

    func compute_raw_withdrawn(withdrawal: Withdrawal) : Float {
        let ratio_removed = Float.fromInt(withdrawal.transferred) / Float.fromInt(withdrawal.due);
        let raw_withdrawn = ratio_removed * Float.fromInt(withdrawal.supplied);
        if (raw_withdrawn < 0.0){
            Debug.trap("Logic error: supply removed shall never be negative");
        };
        raw_withdrawn;
    };

};