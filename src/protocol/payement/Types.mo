import Types         "../Types";

import Result        "mo:base/Result";

import ICRC1         "mo:icrc1-mo/ICRC1/service";
import ICRC2         "mo:icrc2-mo/ICRC2/service";

module {

    type Result<Ok, Err> = Result.Result<Ok, Err>;

    public type Account = ICRC1.Account;
    public type TxIndex = ICRC1.TxIndex;
    public type TransferFromError = ICRC2.TransferFromError;
    public type Transfer = Types.Transfer;
    public type TransferFromResult = Result<TxIndex, TransferFromError>;

    public type TransferFromArgs = {
        from: Account;
        amount: Nat;
    };

    public type TransferArgs = {
        to: Account;
        amount: Nat;
    };

    public type ILedgerFacade = {
        get_balance() : Nat;
        transfer_from(TransferFromArgs) : async* TransferFromResult;
        transfer(TransferArgs) : async* Transfer;
    };

};