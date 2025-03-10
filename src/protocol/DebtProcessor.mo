import Types "Types";
import Timeline "utils/Timeline";
import Register "utils/Register";
import LedgerFacade "payement/LedgerFacade";

import Set "mo:map/Set";
import Array "mo:base/Array";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Debug "mo:base/Debug";
import Option "mo:base/Option";

module {

    type Timeline<T> = Types.Timeline<T>;
    type Account = Types.Account;
    type DebtInfo = Types.DebtInfo;
    type TxIndex = Types.TxIndex;
    type Register<T> = Types.Register<T>;

    type Set<K> = Set.Set<K>;
    type TransferCallback = ({amount: Nat;}) -> ();

    // TODO: Add a pruned flag to be able to remove debts once they are fully paid
    public class DebtProcessor({
        ledger: LedgerFacade.LedgerFacade;
        register: Register<DebtInfo> and { owed: Set<Nat> };
        on_successful_transfer: ?(TransferCallback);
    }){

        public func new_debt({ time: Nat; account: Account; }) : Nat {
            Register.add(register, init_debt_info(time, account));
        };

        public func get_debt({ id: Nat; }) : DebtInfo {
            get_debt_info(id);
        };

        public func increase_debt({ id: Nat; amount: Float; time: Nat; }) {
            let info = get_debt_info(id);
            Timeline.upsert(info.amount, time, amount, Float.add);
            info.owed += amount;
            tag_to_transfer(id, info);
        };

        // TODO: ideally use icrc3 to perform multiple transfers at once
        public func transfer_owed() : async* () {
            let calls = Buffer.Buffer<async* ()>(Set.size(register.owed));
            label infinite while(true){
                switch(Set.pop(register.owed, Set.nhash)){
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

        public func get_owed() : [Nat] {
            Set.toArray(register.owed);
        };

        public func get_ledger() : LedgerFacade.LedgerFacade {
            ledger;
        };

        func transfer(id: Nat) : async* () {
            let info = get_debt_info(id);
            let difference : Nat = Int.abs(Float.toInt(info.owed)) - info.pending;
            info.pending += difference;
            // Remove the debt from the set, it will be added back if the transfer fails
            Set.delete(register.owed, Set.nhash, id);
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

        func get_debt_info(id: Nat) : DebtInfo {
            switch(Register.find(register, id)){
                case(null) { Debug.trap("Debt not found"); };
                case(?info) { info; };
            };
        };

        func tag_to_transfer(id: Nat, info: DebtInfo) {
            if (info.owed > 1.0) {
                Set.add(register.owed, Set.nhash, id);
            } else {
                Set.delete(register.owed, Set.nhash, id);
            };
        };

        func init_debt_info(time: Nat, account: Account) : DebtInfo {
            {
                amount = Timeline.initialize<Float>(time, 0.0);
                account;
                var owed = 0.0;
                var pending = 0;
                var transfers = [];
            };
        };

    };

};