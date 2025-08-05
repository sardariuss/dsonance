import Types         "../Types";
import KongTypes     "../kong/Types";

import Result        "mo:base/Result";

import ICRC1         "mo:icrc1-mo/ICRC1/service";
import ICRC2         "mo:icrc2-mo/ICRC2/service";

module {

    public type Result<Ok, Err> = Result.Result<Ok, Err>;

    public type Account = ICRC1.Account;
    public type TxIndex = ICRC1.TxIndex;
    public type Icrc1TransferArgs = ICRC1.TransferArgs;
    public type Icrc1TransferResult = ICRC1.TransferResult;
    public type TransferError = ICRC1.TransferError;
    public type TransferFromError = ICRC2.TransferFromError;
    public type TransferResult = Types.TransferResult;
    public type Transfer = Types.Transfer;
    public type TransferFromArgs = ICRC2.TransferFromArgs;
    public type PullResult = Result<TxIndex, Text>;

    public type PullArgs = {
        from: Account;
        amount: Nat;
    };

    public type TransferArgs = {
        to: Account;
        amount: Nat;
    };

    public type IPriceTracker = {
        fetch_price: () -> async* Result<(), Text>;
        get_price: () -> Float;
    };

    public type TrackedPrice = {
        var value: ?Float;
    };

    public type SwapPayload = {
        from: Account;
        pay_ledger: ILedgerFungible;
        amount: Nat;
        max_slippage: Float;
        dex: IDex;
        callback: () -> ();
    };

    public type Swap = {
        against: (ISwapReceivable) -> async* Result<SwapReply, Text>;
    };

    public type PrepareSwapArgs = {
        dex: IDex;
        amount: Nat;
        max_slippage: Float;
    };

    public type AugmentedSwapArgs = KongTypes.SwapArgs and { from: Account; }; // For unit testing purposes
    public type SwapAmountsReply = KongTypes.SwapAmountsReply;
    public type SwapReply = KongTypes.SwapReply;

    public type IDex = {
        swap_amounts: (Text, Nat, Text) -> async* Result<SwapAmountsReply, Text>;
        swap: AugmentedSwapArgs -> async* Result<SwapReply, Text>;
        get_main_account: () -> Account;
    };

    public type Value = { #Nat : Nat; #Int : Int; #Blob : Blob; #Text : Text; #Array : [Value]; #Map: [(Text, Value)] };

    public type ApproveArgs = {
        from_subaccount : ?Blob;
        spender : Account;
        amount : Nat;
        expected_allowance : ?Nat;
        expires_at : ?Nat64;
        fee : ?Nat;
        memo : ?Blob;
        created_at_time : ?Nat64;
    };

    public type ApproveError = {
        #BadFee : { expected_fee : Nat };
        #InsufficientFunds : { balance : Nat };
        #AllowanceChanged : { current_allowance : Nat };
        #Expired : { ledger_time : Nat64 };
        #TooOld;
        #CreatedInFuture : { ledger_time : Nat64 };
        #Duplicate : { duplicate_of : Nat };
        #TemporarilyUnavailable;
        #GenericError : { error_code : Nat; message : Text };
    };

    public type ApproveResult = { #Ok : Nat; #Err : ApproveError };

    public type LedgerFungibleActor = actor {
        icrc1_balance_of : shared query Account -> async Nat;
        icrc1_transfer: shared (Icrc1TransferArgs) -> async Icrc1TransferResult;
        icrc2_transfer_from: shared (TransferFromArgs) -> async {#Err : TransferFromError; #Ok : Nat};
        icrc2_approve: shared (ApproveArgs) -> async ApproveResult;
        icrc1_fee : shared query () -> async Nat;
        icrc1_decimals : shared query () -> async Nat8;
        icrc1_metadata : shared query () -> async [(Text, Value)];
    };

    public type LedgerInfo = {
        fee : Nat;
        token_symbol : Text;
        decimals : Nat8;
    };

    public type ILedgerFungible = {
        balance_of: (Account) -> async* Nat;
        transfer: (Icrc1TransferArgs) -> async* Result<Nat, Text>;
        transfer_no_commit: (Icrc1TransferArgs) -> async Result<Nat, Text>;
        transfer_from: (TransferFromArgs) -> async* Result<Nat, Text>;
        approve: (ApproveArgs) -> async* Result<Nat, Text>;
        get_token_info: () -> LedgerInfo;
    };

    public type ILedgerAccount = {
        get_local_balance: () -> Nat;
        pull: (PullArgs) -> async* PullResult;
        transfer: (TransferArgs) -> async* Transfer;
        transfer_no_commit: (TransferArgs) -> async Transfer;
        approve: { spender: Account; amount: Nat; } -> async* Result<TxIndex, Text>;
        token_symbol: () -> Text;
    };

    public type ISwapPayable = {
        swap: (PrepareSwapArgs) -> Swap;
    };

    public type ISwapReceivable = {
        perform_swap: (SwapPayload) -> async* Result<SwapReply, Text>;
    };

    public type ProtocolInfo = {
        principal: Principal;
        supply: {
            subaccount: ?Blob;
            local_balance: {
                var value: Nat;
            };
        };
        collateral: {
            subaccount: ?Blob;
            local_balance: {
                var value: Nat;
            };
        };
    };

};