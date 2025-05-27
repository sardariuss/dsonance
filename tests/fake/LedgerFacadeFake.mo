import Debug "mo:base/Debug";
import Map "mo:map/Map";
import Int "mo:base/Int";
import Option "mo:base/Option";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import PayementTypes "../../src/protocol/payement/Types";
import MapUtils "../../src/protocol/utils/Map";
import Testify "../utils/Testify";

module {

    type ILedgerFacade      = PayementTypes.ILedgerFacade;
    type TransferFromArgs   = PayementTypes.TransferFromArgs;
    type TransferArgs       = PayementTypes.TransferArgs;
    type Transfer           = PayementTypes.Transfer;
    type TransferFromResult = PayementTypes.TransferFromResult;
    type Account            = PayementTypes.Account;

    type LedgerBalances = {
        protocol: Nat;
        users: [(Account, Nat)];
    };

    public let testify_ledger_balances = {
        equal : Testify.Testify<LedgerBalances> = {
            toText = func (u : LedgerBalances) : Text {
                let user_balances = Array.map(u.users, func(pair: (Account, Nat)) : Text {
                    debug_show(pair);
                });
                "LedgerBalances { protocol = " # Nat.toText(u.protocol) # 
                ", users = " # "[ " # Text.join(", ", user_balances.vals()) # " ]";
            };
            compare = func (x : LedgerBalances, y : LedgerBalances) : Bool {
                let users_x = Map.fromIter<Account, Nat>(x.users.vals(), MapUtils.acchash);
                let users_y = Map.fromIter<Account, Nat>(y.users.vals(), MapUtils.acchash);
                (x.protocol == y.protocol) and 
                MapUtils.compare(users_x, users_y, MapUtils.acchash, func(a: Nat, b: Nat) : Bool {
                    a == b;
                });
            };
        };
    };

    public class LedgerFacadeFake(initial_balances: LedgerBalances) : ILedgerFacade {
        
        var tx_id = 0;
        var balance = initial_balances.protocol;
        let user_balances : Map.Map<Account, Nat> = Map.fromIter(Array.vals(initial_balances.users), MapUtils.acchash);

        public func add_balance(amount: Nat) {
            balance += amount;
        };

        public func sub_balance(amount: Nat) {
            if (amount > balance) {
                Debug.trap("Not enough balance to subtract " # debug_show(amount));
            };
            balance -= amount;
        };

        public func get_balances() : LedgerBalances {
            {
                protocol = balance;
                users = Map.toArray(user_balances);
            };
        };

        public func get_balance() : Nat {
            balance;
        };

        public func transfer(args: TransferArgs) : async* Transfer {
            // Add to user balance
            let user_balance = Option.get(Map.get(user_balances, MapUtils.acchash, args.to), 0);
            let new_balance = user_balance + args.amount;
            Map.set(user_balances, MapUtils.acchash, args.to, new_balance);

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
            // Remove from user balance if enough
            let user_balance = Option.get(Map.get(user_balances, MapUtils.acchash, args.from), 0);
            let diff : Int = user_balance - args.amount;
            if (diff < 0) {
                return #err(#GenericError({
                    message = "Insufficient funds";
                    error_code = 0
                }));
            };
            if (diff == 0) {
                Map.delete(user_balances, MapUtils.acchash, args.from);
            } else {
                Map.set(user_balances, MapUtils.acchash, args.from, Int.abs(diff));
            };
            balance += args.amount;
            #ok(next_tx_id());
        };

        func next_tx_id() : Nat {
            tx_id += 1;
            tx_id;
        };
    };

}