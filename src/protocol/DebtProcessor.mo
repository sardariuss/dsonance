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
    type DebtRegister = Types.DebtRegister;

    type TransferCallback = ({amount: Nat;}) -> ();

    // TODO: instead of transfering all the debts on transfer_pending, only the finalized
    // debts should be transferred. However, if a debt is not finalized, a user shall be
    // able to transfer the own amount manually.
    public class DebtProcessor({
        ledger: LedgerFacade.LedgerFacade;
        register: DebtRegister;
        on_successful_transfer: ?(TransferCallback);
    }){

        public func new_debt({ time: Nat; account: Account; }) : Nat {
            let info : DebtInfo = {
                amount = Timeline.initialize<Float>(time, 0.0);
                account;
                var transferred = 0;
                var transfers = [];
                var finalized = false;
            };
            Register.add(register, info);
        };

        public func one_shot_debt({ time: Nat; account: Account; amount: Float; }) : Nat {
            let info : DebtInfo = {
                amount = Timeline.initialize<Float>(time, amount);
                account;
                var transferred = 0;
                var transfers = [];
                var finalized = true;
            };
            let id = Register.add(register, info);
            Set.add(register.pending_transfer, Set.nhash, id);
            id;
        };

        public func get_debt({ id: Nat; }) : DebtInfo {
            get_debt_info(id);
        };

        public func increase_debt({ id: Nat; amount: Float; time: Nat; finalized: Bool; }) {
            let info = get_debt_info(id);
            if (info.finalized) {
                Debug.trap("Cannot increase a finalized debt.");
            };
            Timeline.accumulate(info.amount, time, amount, Float.add);
            info.finalized := finalized;
            Set.add(register.pending_transfer, Set.nhash, id);
        };

        // TODO: ideally use icrc3 to perform multiple transfers at once
        public func transfer_pending() : async* () {
            let calls = Buffer.Buffer<async* ()>(Set.size(register.pending_transfer));
            label infinite while(true){
                switch(Set.pop(register.pending_transfer, Set.nhash)){
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

        public func get_ledger() : LedgerFacade.LedgerFacade {
            ledger;
        };

        func transfer(id: Nat) : async* () {
            let info = get_debt_info(id);
            let difference = info.transferred - Int.abs(Float.toInt(Timeline.current(info.amount)));
            
            if (difference < 0) {
                Debug.trap("Debt is negative");
            };

            // Remove the debt from the set, it will be added back if the transfer fails
            Set.delete(register.pending_transfer, Set.nhash, id);

            // Do not transfer if the difference is less than 1.0
            if (difference < 1) {
                return;
            };

            let transfer = await* ledger.transfer({ to = info.account; amount = difference; });
            
            info.transfers := Array.append(info.transfers, [transfer]);
            
            // Update what is owed if the transfer succeded
            Result.iterate(transfer.result, func(_: TxIndex){
                info.transferred += difference;
                
                // Remove the debt from the map if it has been finalized
                if (info.finalized) {
                    Register.delete(register, id);
                };

                // Notify the callback if there is one
                Option.iterate(on_successful_transfer, func(f: TransferCallback){
                    f({ amount = difference; });
                });
            });
        };

        func get_debt_info(id: Nat) : DebtInfo {
            switch(Register.find(register, id)){
                case(null) { Debug.trap("Debt not found"); };
                case(?info) { info; };
            };
        };

    };

};