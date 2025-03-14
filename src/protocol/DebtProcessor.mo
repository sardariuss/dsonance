import Types "Types";
import Timeline "utils/Timeline";
import LedgerFacade "payement/LedgerFacade";

import Set "mo:map/Set";
import Map "mo:map/Map";
import Array "mo:base/Array";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Debug "mo:base/Debug";
import Option "mo:base/Option";

module {

    type UUID = Types.UUID;
    type Timeline<T> = Types.Timeline<T>;
    type Account = Types.Account;
    type DebtInfo = Types.DebtInfo;
    type TransferResult = Types.TransferResult;
    type TxIndex = Types.TxIndex;

    type Set<K> = Set.Set<K>;
    type Map<K, V> = Map.Map<K, V>;

    type TransferCallback = ({amount: Nat;}) -> ();

    public func init_debt_info(time: Nat, account: Account) : DebtInfo {
        {
            amount = Timeline.initialize<Float>(time, 0.0);
            account;
            var owed = 0.0;
            var pending = 0;
            var transfers = [];
        };
    };

    public class DebtProcessor({
        ledger: LedgerFacade.LedgerFacade;
        get_debt_info: (UUID) -> DebtInfo;
        owed: Set<UUID>;
        on_successful_transfer: ?(TransferCallback);
    }){

        public func add_debt({ id: UUID; amount: Float; time: Nat; }) {
            let info = get_debt_info(id);
            Timeline.add(info.amount, time, Timeline.current(info.amount) + amount);
            info.owed += amount;
            tag_to_transfer(id, info);
        };

        // TODO: ideally use icrc3 to perform multiple transfers at once
        public func transfer_owed() : async* () {
            let calls = Buffer.Buffer<async* ()>(Set.size(owed));
            label infinite while(true){
                switch(Set.pop(owed, Map.thash)){
                    case(null) { 
                        Debug.print("No more debts to transfer");
                        break infinite; 
                    };
                    case(?id) {
                        Debug.print("Transferring debt for id: " # debug_show(id));
                        calls.add(transfer(id));
                    };
                };
            };
            for (call in calls.vals()){
                await* call;
            };
        };

        public func get_owed() : [UUID] {
            Set.toArray(owed);
        };

        public func get_ledger() : LedgerFacade.LedgerFacade {
            ledger;
        };

        func transfer(id: UUID) : async* () {
            let info = get_debt_info(id);
            let difference : Nat = Int.abs(Float.toInt(info.owed)) - info.pending;
            info.pending += difference;
            // Remove the debt from the set, it will be added back if the transfer fails
            Set.delete(owed, Map.thash, id);
            // Run the transfer
            let transfer = await* ledger.transfer({ to = info.account; amount = difference; });
            info.transfers := Array.append(info.transfers, [transfer]);
            info.pending -= difference;
            // Update what is owed if the transfer succeded
            Result.iterate(transfer.result, func(_: TxIndex){
                info.owed -= Float.fromInt(difference);
                // Notify the callback if there is one
                Option.iterate(on_successful_transfer, func(f: TransferCallback){
                    f({ amount = difference; });
                });
            });
            // Add the debt back in case there is still something owed
            tag_to_transfer(id, info);
        };

        func tag_to_transfer(id: UUID, info: DebtInfo) {
            if (info.owed > 1.0) {
                Set.add(owed, Map.thash, id);
            } else {
                Set.delete(owed, Map.thash, id);
            };
        };

    };

};