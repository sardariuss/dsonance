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

    public let testify_ledger_balances = {
        equal : Testify.Testify<[(Account, Nat)]> = {
            toText = func (u : [(Account, Nat)]) : Text {
                let user_balances = Array.map(u, func(pair: (Account, Nat)) : Text {
                    debug_show(pair);
                });
                "LedgerBalances [ " # Text.join(", ", user_balances.vals()) # " ]";
            };
            compare = func (x : [(Account, Nat)], y : [(Account, Nat)]) : Bool {
                let users_x = Map.fromIter<Account, Nat>(x.vals(), MapUtils.acchash);
                let users_y = Map.fromIter<Account, Nat>(y.vals(), MapUtils.acchash);
                MapUtils.compare(users_x, users_y, MapUtils.acchash, func(a: Nat, b: Nat) : Bool {
                    a == b;
                });
            };
        };
    };

    public class LedgerFungibleFake(protocol_account: Account, initial_balances: [(Account, Nat)]) : ILedgerFungible {
        var tx_id = 0;
        let balances : Map.Map<Account, Nat> = Map.fromIter(Array.vals(initial_balances), MapUtils.acchash);

        public func get_balances() : [(Account, Nat)] {
            Map.toArray(balances);
        };

        public func icrc1_transfer(args : Icrc1TransferArgs) : async* Result<TxIndex, TransferError> {
            // Subtract from protocol_account
            let protocol_balance = Option.get(Map.get(balances, MapUtils.acchash, protocol_account), 0);
            let new_protocol_balance : Int = protocol_balance - args.amount;
            if (new_protocol_balance < 0) {
                return #err(#GenericError({
                    message = "Not enough balance to transfer " # debug_show(args.amount) # " from protocol_account " # debug_show(protocol_account) # " to " # debug_show(args.to);
                    error_code = 0;
                }));
            };
            if (new_protocol_balance == 0) {
                Map.delete(balances, MapUtils.acchash, protocol_account);
            } else {
                Map.set(balances, MapUtils.acchash, protocol_account, Int.abs(new_protocol_balance));
            };
            // Add to recipient
            let to_balance = Option.get(Map.get(balances, MapUtils.acchash, args.to), 0) + args.amount;
            Map.set(balances, MapUtils.acchash, args.to, to_balance);
            #ok(next_tx_id());
        };

        public func icrc2_transfer_from(args : TransferFromArgs) : async* Result<TxIndex, TransferFromError> {
            // Remove from 'from' account
            let from_balance = Option.get(Map.get(balances, MapUtils.acchash, args.from), 0);
            let diff : Int = from_balance - args.amount;
            if (diff < 0) {
                return #err(#GenericError({
                    message = "Not enough balance to transfer " # debug_show(args.amount) # " from " # debug_show(args.from) # " to protocol_account " # debug_show(protocol_account);
                    error_code = 0
                }));
            };
            if (diff == 0) {
                Map.delete(balances, MapUtils.acchash, args.from);
            } else {
                Map.set(balances, MapUtils.acchash, args.from, Int.abs(diff));
            };
            // Add to protocol_account
            let protocol_balance = Option.get(Map.get(balances, MapUtils.acchash, protocol_account), 0) + args.amount;
            Map.set(balances, MapUtils.acchash, protocol_account, protocol_balance);
            #ok(next_tx_id());
        };

        func next_tx_id() : Nat {
            tx_id += 1;
            tx_id;
        };
    };

}