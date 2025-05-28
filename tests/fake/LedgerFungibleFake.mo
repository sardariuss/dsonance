import Map "mo:map/Map";
import Int "mo:base/Int";
import Option "mo:base/Option";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Result "mo:base/Result";
import LedgerTypes "../../src/protocol/ledger/Types";
import MapUtils "../../src/protocol/utils/Map";
import Testify "../utils/Testify";

module {

    type Result<Ok, Err>    = Result.Result<Ok, Err>;
    type ILedgerAccount     = LedgerTypes.ILedgerAccount;
    type PullArgs           = LedgerTypes.PullArgs;
    type TransferArgs       = LedgerTypes.TransferArgs;
    type Transfer           = LedgerTypes.Transfer;
    type PullResult         = LedgerTypes.PullResult;
    type Account            = LedgerTypes.Account;
    type Icrc1TransferArgs  = LedgerTypes.Icrc1TransferArgs;
    type TxIndex            = LedgerTypes.TxIndex;
    type TransferError      = LedgerTypes.TransferError;
    type TransferFromArgs   = LedgerTypes.TransferFromArgs;
    type TransferFromError  = LedgerTypes.TransferFromError;
    type ILedgerFungible    = LedgerTypes.ILedgerFungible;

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

    public class LedgerFungibleFake(initial_balances: LedgerBalances) : ILedgerFungible {
        
        var tx_id = 0;
        var balance = initial_balances.protocol;
        let user_balances : Map.Map<Account, Nat> = Map.fromIter(Array.vals(initial_balances.users), MapUtils.acchash);

        public func get_balances() : LedgerBalances {
            {
                protocol = balance;
                users = Map.toArray(user_balances);
            };
        };

        public func icrc1_transfer(args : Icrc1TransferArgs) : async* Result<TxIndex, TransferError> {
            
            if (args.amount > balance) {
                return #err(#GenericError({
                    message = "Not enough balance to transfer " # debug_show(args.amount) # " from protocol to " # debug_show(args.to);
                    error_code = 0;
                }));
            };
            balance -= args.amount;

            // Add to user balance
            var user_balance = Option.get(Map.get(user_balances, MapUtils.acchash, args.to), 0);
            user_balance += args.amount;
            Map.set(user_balances, MapUtils.acchash, args.to, user_balance);
            
            #ok(next_tx_id());
        };

        public func icrc2_transfer_from(args : TransferFromArgs) : async* Result<TxIndex, TransferFromError> {
            // Remove from user balance if enough
            let user_balance = Option.get(Map.get(user_balances, MapUtils.acchash, args.from), 0);
            let diff : Int = user_balance - args.amount;
            if (diff < 0) {
                return #err(#GenericError({
                    message = "Not enough balance to transfer " # debug_show(args.amount) # " from " # debug_show(args.from) # " to protocol";
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