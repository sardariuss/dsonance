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

    public let testify_balances = {
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

    public class LedgerAccounting(initial_balances: [(Account, Nat)]) {
        
        var tx_id : Nat = 0;
        let map_balances : Map.Map<Account, Nat> = Map.fromIter(Array.vals(initial_balances), MapUtils.acchash);

        public func balances() : [(Account, Nat)] {
            Map.toArray(map_balances);
        };

        public func transfer({ from: Account; to: Account; amount: Nat; }) : Result<TxIndex, TransferError> {
            // Subtract from protocol_account
            var from_balance : Int = Option.get(Map.get(map_balances, MapUtils.acchash, from), 0);
            from_balance -= amount;
            if (from_balance < 0) {
                return #err(#GenericError({
                    message = "Not enough balance to transfer " # debug_show(amount) # " from " # debug_show(from) # " to " # debug_show(to);
                    error_code = 0;
                }));
            };
            if (from_balance == 0) {
                Map.delete(map_balances, MapUtils.acchash, from);
            } else {
                Map.set(map_balances, MapUtils.acchash, from, Int.abs(from_balance));
            };
            // Add to recipient
            let to_balance = Option.get(Map.get(map_balances, MapUtils.acchash, to), 0) + amount;
            Map.set(map_balances, MapUtils.acchash, to, to_balance);
            #ok(next_tx_id());
        };

        func next_tx_id() : Nat {
            tx_id += 1;
            tx_id;
        };
    };

}