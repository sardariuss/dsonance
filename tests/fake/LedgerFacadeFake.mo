import Debug "mo:base/Debug";

import PayementTypes "../../src/protocol/payement/Types";

module {

    type ILedgerFacade      = PayementTypes.ILedgerFacade;
    type TransferFromArgs   = PayementTypes.TransferFromArgs;
    type TransferArgs       = PayementTypes.TransferArgs;
    type Transfer           = PayementTypes.Transfer;
    type TransferFromResult = PayementTypes.TransferFromResult;
    
    public class LedgerFacadeFake() : ILedgerFacade {
        
        var balance: Nat = 0;
        var tx_id: Nat = 0;

        public func add_balance(amount: Nat) {
            balance += amount;
        };

        public func sub_balance(amount: Nat) {
            if (amount > balance) {
                Debug.trap("Not enough balance to subtract " # debug_show(amount));
            };
            balance -= amount;
        };

        public func get_balance() : Nat {
            balance;
        };

        public func transfer(args: TransferArgs) : async* Transfer {
            if (args.amount > balance) {
                Debug.trap("Not enough balance to transfer " # debug_show(args.amount) # " to " # debug_show(args.to));
            };
            balance -= args.amount;
            { 
                args = {
                    args with
                    from_subaccount = null;
                    fee = null;
                    memo = null;
                    created_at_time = null;
                };
                result = #ok(next_tx_id());
            };
        };

        public func transfer_from(args: TransferFromArgs) : async* TransferFromResult {
            balance += args.amount;
            #ok(next_tx_id());
        };

        func next_tx_id() : Nat {
            tx_id += 1;
            tx_id;
        };
    };

}