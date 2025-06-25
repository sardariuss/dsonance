
import Result "mo:base/Result";
import LedgerTypes "../../src/protocol/ledger/Types";
import LedgerAccounting "LedgerAccounting";

module {
    
    type Result<Ok, Err>    = Result.Result<Ok, Err>;
    type Account            = LedgerTypes.Account;
    type Icrc1TransferArgs  = LedgerTypes.Icrc1TransferArgs;
    type TxIndex            = LedgerTypes.TxIndex;
    type TransferError      = LedgerTypes.TransferError;
    type TransferFromArgs   = LedgerTypes.TransferFromArgs;
    type TransferFromError  = LedgerTypes.TransferFromError;
    type ILedgerFungible    = LedgerTypes.ILedgerFungible;

    type Info = {
        account: Account;
        ledger_accounting: LedgerAccounting.LedgerAccounting;
        fee: Nat;
        token_symbol: Text;
    };

    public class LedgerFungibleFake(info: Info) : ILedgerFungible {

        public func fee() : Nat {
            info.fee;
        };
        
        public func token_symbol() : Text {
            info.token_symbol;
        };

        public func balance_of(account: Account) : async* Nat {
            info.ledger_accounting.get_balance(account);
        };

        public func transfer(args : Icrc1TransferArgs) : async* Result<TxIndex, TransferError> {
            info.ledger_accounting.transfer({
                from = info.account;
                to = args.to;
                amount = args.amount;
            });
        };

        public func transfer_from(args : TransferFromArgs) : async* Result<TxIndex, TransferFromError> {
            info.ledger_accounting.transfer({
                from = args.from;
                to = info.account;
                amount = args.amount;
            });
        };

    };

}