import Types "Types";
import Timeline "utils/Timeline";
import LedgerAccount "ledger/LedgerAccount";

import Array "mo:base/Array";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Debug "mo:base/Debug";
import Option "mo:base/Option";
import Nat "mo:base/Nat";

import Map "mo:map/Map";
import Set "mo:map/Set";

module {

    type Timeline<T> = Types.Timeline<T>;
    type Account = Types.Account;
    type DebtInfo = Types.DebtInfo;
    type TxIndex = Types.TxIndex;
    type UUID = Types.UUID;
    type DebtRecord = Types.DebtRecord;
    type Map<K, V> = Map.Map<K, V>;
    type Set<T> = Set.Set<T>;

    type DebtRegister = {
        debts: Map<UUID, DebtInfo>;
        pending_transfer: Set<UUID>;
    };

    type TransferCallback = ({amount: Nat;}) -> ();

    public class DebtProcessor({
        ledger: LedgerAccount.LedgerAccount;
        register: DebtRegister;
    }){

        public func increase_debt({ id: UUID; time: Nat; account: Account; amount: Float; pending: Float; }) {

            // Update or create the debt info
            switch(Map.get(register.debts, Map.thash, id)){
                case(?debt_info) {
                    let current_debt = debt_info.amount.current;
                    switch(Nat.compare(time, current_debt.timestamp)){
                        case(#less) {
                            Debug.trap("The timestamp must be greater than or equal to the current timestamp");
                        };
                        case(#equal){
                            debt_info.amount.current := {
                                timestamp = time;
                                data = { 
                                    earned = current_debt.data.earned + amount;
                                    pending = current_debt.data.pending + pending;
                                };
                            };
                        };
                        case(#greater){
                            Timeline.insert(debt_info.amount, time, { 
                                earned = current_debt.data.earned + amount;
                                pending; // Reset pending
                            });
                        };
                    };
                };
                case(null) { 
                    let debt_info : DebtInfo = {
                        id;
                        amount = Timeline.initialize<DebtRecord>(time, { earned = amount; pending; });
                        account;
                        var transferred = 0;
                        var transfers = [];
                    };
                    Map.set(register.debts, Map.thash, id, debt_info);
                };
            };

            // Add to transfer queue
            Set.add(register.pending_transfer, Set.thash, id);
        };

        // TODO: ideally use icrc4 to perform multiple transfers at once
        public func transfer_pending() : async* () {
            let calls = Buffer.Buffer<async* ()>(Set.size(register.pending_transfer));
            label infinite while(true){
                switch(Set.pop(register.pending_transfer, Set.thash)){
                    case(null) { 
                        Debug.print("No more debts to transfer");
                        break infinite; 
                    };
                    case(?id) {
                        Debug.print("Transferring debt for id: " # debug_show(id));
                        switch(Map.get(register.debts, Map.thash, id)){
                            case(null) { 
                                Debug.trap("DebtInfo not found");
                            };
                            case(?debt_info) { 
                                calls.add(transfer(debt_info));
                            };
                        };
                    };
                };
            };
            for (call in calls.vals()){
                await* call;
            };
        };

        public func get_ledger() : LedgerAccount.LedgerAccount {
            ledger;
        };

        func transfer(debt_info: DebtInfo) : async* () {

            let difference = Int.abs(Float.toInt(Timeline.current(debt_info.amount).earned)) - debt_info.transferred;

            // Remove the debt from the set, it will be added back if the transfer fails
            Set.delete(register.pending_transfer, Set.thash, debt_info.id);

            // The conversion from Float to Int may result in a difference of 0, in which case
            // there is no need to transfer anything
            if (difference == 0) {
                return;
            };

            let transfer = await* ledger.transfer({ to = debt_info.account; amount = difference; });
            
            // Add the transfer to the list of transfers
            debt_info.transfers := Array.append(debt_info.transfers, [transfer]);
            
            Result.iterate(transfer.result, func(_: TxIndex){
                
                // Update successfully transferred amount
                debt_info.transferred += difference;
            });
        };

    };

};