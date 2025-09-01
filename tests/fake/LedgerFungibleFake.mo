
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
    type ApproveArgs        = LedgerTypes.ApproveArgs;
    type ApproveError       = LedgerTypes.ApproveError;
    type ILedgerFungible    = LedgerTypes.ILedgerFungible;
    type LedgerInfo         = LedgerTypes.LedgerInfo;

    type Info = {
        account: Account;
        ledger_accounting: LedgerAccounting.LedgerAccounting;
        ledger_info: LedgerInfo;
    };

    public class LedgerFungibleFake(info: Info) : ILedgerFungible {

        public func get_token_info() : LedgerInfo {
            info.ledger_info;
        };

        public func balance_of(account: Account) : async* Nat {
            info.ledger_accounting.get_balance(account);
        };

        public func transfer(args : Icrc1TransferArgs) : async* Result<Nat, Text> {
            switch(info.ledger_accounting.transfer({
                from = info.account;
                to = args.to;
                amount = args.amount;
            })) {
                case (#ok(tx_id)) { #ok(tx_id) };
                case (#err(error)) { #err(convert_transfer_error_to_text(error)) };
            };
        };

        public func transfer_from(args : TransferFromArgs) : async* Result<Nat, Text> {
            switch(info.ledger_accounting.transfer({
                from = args.from;
                to = info.account;
                amount = args.amount;
            })) {
                case (#ok(tx_id)) { #ok(tx_id) };
                case (#err(error)) { #err(convert_transfer_error_to_text(error)) };
            };
        };

        public func approve(_ : ApproveArgs) : async* Result<Nat, Text> {
            // For the fake implementation, just return success with a dummy transaction index
            #ok(42);
        };

        private func convert_transfer_error_to_text(error: TransferError) : Text {
            switch(error) {
                case (#GenericError({message; error_code})) { "Generic error " # debug_show(error_code) # ": " # message };
                case (#BadFee({expected_fee})) { "Bad fee: expected " # debug_show(expected_fee) };
                case (#BadBurn({min_burn_amount})) { "Bad burn: minimum amount " # debug_show(min_burn_amount) };
                case (#InsufficientFunds({balance})) { "Insufficient funds: balance " # debug_show(balance) };
                case (#Duplicate({duplicate_of})) { "Duplicate transaction: " # debug_show(duplicate_of) };
                case (#TemporarilyUnavailable) { "Service temporarily unavailable" };
                case (#TooOld) { "Transaction too old" };
                case (#CreatedInFuture({ledger_time})) { "Transaction created in future: " # debug_show(ledger_time) };
            };
        };

    };

}