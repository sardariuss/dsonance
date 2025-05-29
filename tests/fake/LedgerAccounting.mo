import Map "mo:map/Map";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
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

    type NamedAccount = Account and { name: Text; };

    type AccountInfo = {
        name: Text;
        balance: Nat;
    };

    public let testify_balances = {
        equal : Testify.Testify<[(NamedAccount, Nat)]> = {
            toText = func (u : [(NamedAccount, Nat)]) : Text {
                let user_balances = Array.map(u, func(pair: (NamedAccount, Nat)) : Text {
                    debug_show(pair.0.name) # ": " # debug_show(pair.1);
                });
                "LedgerBalances [ " # Text.join(", ", user_balances.vals()) # " ]";
            };
            compare = func (x : [(NamedAccount, Nat)], y : [(NamedAccount, Nat)]) : Bool {
                let users_x = Map.fromIter<Text, Nat>(Array.map<(NamedAccount, Nat), (Text, Nat)>(x, func((account, balance): (NamedAccount, Nat)) : (Text, Nat) { (account.name, balance); }).vals(), Map.thash);
                let users_y = Map.fromIter<Text, Nat>(Array.map<(NamedAccount, Nat), (Text, Nat)>(y, func((account, balance): (NamedAccount, Nat)) : (Text, Nat) { (account.name, balance); }).vals(), Map.thash);
                MapUtils.compare(users_x, users_y, Map.thash, func(a: Nat, b: Nat) : Bool {
                    a == b;
                });
            };
        };
    };

    public class LedgerAccounting(initial_info: [(NamedAccount, Nat)]) {
        
        var tx_id : Nat = 0;
        let map_infos : Map.Map<Account, AccountInfo> = Map.fromIter(Array.vals(Array.map<(NamedAccount, Nat),(Account, AccountInfo)>(initial_info, func((named_account, balance) : (NamedAccount, Nat)) : (Account, AccountInfo) {
            (
                named_account, 
                {
                    name = named_account.name;
                    balance = balance;
                }
            );
        })), MapUtils.acchash);

        public func balances() : [(NamedAccount, Nat)] {
            Array.map<(Account, AccountInfo),(NamedAccount, Nat)>(Iter.toArray(Map.entries(map_infos)), func((account, info) : (Account, AccountInfo)) : (NamedAccount, Nat) {
                (
                    { account with name = info.name; },
                    info.balance
                );
            });
        };

        public func transfer({ from: Account; to: Account; amount: Nat; }) : Result<TxIndex, TransferError> {
            let from_info = switch(Map.get(map_infos, MapUtils.acchash, from)) {
                case(null) {
                    return #err(#GenericError({
                        message = "Account " # debug_show(from) # " not found in ledger accounting";
                        error_code = 0;
                    }));
                };
                case (?info) { info; };
            };
            let to_info = switch(Map.get(map_infos, MapUtils.acchash, to)) {
                case(null) {
                    return #err(#GenericError({
                        message = "Account " # debug_show(to) # " not found in ledger accounting";
                        error_code = 0;
                    }));
                };
                case (?info) { info; };
            };
            // Check if the sender has enough balance
            let new_balance : Int = from_info.balance - amount;
            if (new_balance < 0) {
                return #err(#GenericError({
                    message = "Not enough balance to transfer " # debug_show(amount) # " from " # debug_show(from) # " to " # debug_show(to);
                    error_code = 0;
                }));
            };
            // Remove from sender
            Map.set(map_infos, MapUtils.acchash, from, { from_info with balance = Int.abs(new_balance) });
            // Add to recipient
            Map.set(map_infos, MapUtils.acchash, to, { to_info with balance = to_info.balance + amount });
            #ok(next_tx_id());
        };

        func next_tx_id() : Nat {
            tx_id += 1;
            tx_id;
        };
    };

}