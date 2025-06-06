
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

    public class LedgerFungibleFake(account: Account, ledger_accounting: LedgerAccounting.LedgerAccounting) : ILedgerFungible {

        public func icrc1_balance_of(account: Account) : async* Nat {
            ledger_accounting.get_balance(account);
        };

        public func icrc1_transfer(args : Icrc1TransferArgs) : async* Result<TxIndex, TransferError> {
            ledger_accounting.transfer({
                from = account;
                to = args.to;
                amount = args.amount;
            });
        };

        public func icrc2_transfer_from(args : TransferFromArgs) : async* Result<TxIndex, TransferFromError> {
            ledger_accounting.transfer({
                from = args.from;
                to = account;
                amount = args.amount;
            });
        };

    };

}