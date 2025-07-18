import Types         "../Types";

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
    public type PullResult = Result<TxIndex, TransferFromError>;

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

    public type ITWAPPriceTracker = {
        fetch_price: () -> async* Result<(), Text>;
        get_price: () -> Float;
        get_spot_price: () -> Float;
        get_twap_price: () -> Float;
        get_observations_count: () -> Nat;
    };

    public type TrackedPrice = {
        var value: ?Float;
    };

    public type SwapPayload = {
        from: Account;
        pay_token: Text;
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

    // Copy/pasted from KongSwap: https://dashboard.internetcomputer.org/canister/2ipq2-uqaaa-aaaar-qailq-cai

    public type SwapAmountsTxReply = {
        pool_symbol: Text;
        pay_chain: Text;
        pay_symbol: Text;
        pay_address: Text;
        pay_amount: Nat;
        receive_chain: Text;
        receive_symbol: Text;
        receive_address: Text;
        receive_amount: Nat;
        price: Float;
        lp_fee: Nat;
        gas_fee: Nat;
    };
    public type SwapAmountsReply = {
        pay_chain: Text;
        pay_symbol: Text;
        pay_address: Text;
        pay_amount: Nat;
        receive_chain: Text;
        receive_symbol: Text;
        receive_address: Text;
        receive_amount: Nat;
        price: Float;
        mid_price: Float;
        slippage: Float;
        txs: [SwapAmountsTxReply];
    };
    public type SwapAmountsResult = { 
        #Ok: SwapAmountsReply;
        #Err: Text; 
    };

    public type ICTransferReply = {
        chain : Text;
        symbol : Text;
        is_send : Bool;
        amount : Nat;
        canister_id : Text;
        block_index : Nat;
    };
    public type TransferReply = {
        #IC : ICTransferReply;
    };
    public type TransferIdReply = {
        transfer_id : Nat64;
        transfer : TransferReply
    };

    public type TxId = {
        BlockIndex : Nat;
        TransactionId : Text;
    };

    public type SwapArgs = {
        pay_token: Text;
        pay_amount: Nat;
        pay_tx_id: ?TxId;
        receive_token: Text;
        receive_amount: ?Nat;
        receive_address: ?Text;
        max_slippage: ?Float;
        referred_by: ?Text;
    };

    public type AugmentedSwapArgs = SwapArgs and { from: Account; }; // For unit testing purposes

    public type SwapTxReply = {
        pool_symbol : Text;
        pay_chain : Text;
        pay_address : Text;
        pay_symbol : Text;
        pay_amount : Nat;
        receive_chain : Text;
        receive_address : Text;
        receive_symbol : Text;
        receive_amount : Nat;
        price : Float;
        lp_fee : Nat;
        gas_fee : Nat;
        ts : Nat64;
    };
    public type SwapReply = {
        tx_id : Nat64;
        request_id : Nat64;
        status : Text;
        pay_chain : Text;
        pay_address : Text;
        pay_symbol : Text;
        pay_amount : Nat;
        receive_chain : Text;
        receive_address : Text;
        receive_symbol : Text;
        receive_amount : Nat;
        mid_price : Float;
        price : Float;
        slippage : Float;
        txs : [SwapTxReply];
        transfer_ids : [TransferIdReply];
        claim_ids : [Nat64];
        ts : Nat64;
    };
    public type SwapResult = { 
        #Ok : SwapReply;
        #Err : Text;
    };

    public type PriceArgs = {
        pay_token: Text;
        receive_token: Text;
    };

    public type DexActor = actor {
        // swap_amounts(pay_token, pay_amount, receive_token)
        // pay_token, receive_token - format Symbol, Chain.Symbol, CanisterId or Chain.CanisterId ie. ckBTC, IC.ckBTC, or IC.ryjl3-tyaaa-aaaaa-aaaba-cai
        // pay_amount, receive_amount - Nat numbers with corresponding decimal precision as defined in ledger canister
        // - calculates the expected receive_amount and price of the swap
        // - results of swap_amounts() are then pass to swap() for execution
        swap_amounts: shared (Text, Nat, Text) -> async SwapAmountsResult;

        // swap()
        // pay_token, receive_token - format Symbol, Chain.Symbol, CanisterId or Chain.CanisterId ie. ckBTC, IC.ckBTC, or IC.ryjl3-tyaaa-aaaaa-aaaba-cai
        // pay_amount, receive_amount - Nat numbers with corresponding decimal precision as defined in ledger canister
        // - swaps pay_amount of pay_token into receive_amount of receive_token
        // - swap() has 2 variations:
        //   1) icrc2_approve + icrc2_transfer_from - user must icrc2_approve the pay_amount+gas of pay_token and then call swap() where the canister will then icrc2_transfer_from
        //   2) icrc1_transfer - user must icrc1_transfer the pay_amount of pay_token and then call swap() with the block index
        swap: shared SwapArgs -> async SwapResult;
    };

    public type IDex = {
        swap_amounts: (Text, Nat, Text) -> async* Result<SwapAmountsReply, Text>;
        swap: AugmentedSwapArgs -> async* Result<SwapReply, Text>;
    };

    public type Value = { #Nat : Nat; #Int : Int; #Blob : Blob; #Text : Text; #Array : [Value]; #Map: [(Text, Value)] };

    public type LedgerFungibleActor = actor {
        icrc1_balance_of : shared query Account -> async Nat;
        icrc1_transfer: shared (Icrc1TransferArgs) -> async Icrc1TransferResult;
        icrc2_transfer_from: shared (TransferFromArgs) -> async {#Err : TransferFromError; #Ok : Nat};
        icrc1_fee : shared query () -> async Nat;
        icrc1_metadata : shared query () -> async [(Text, Value)];
    };

    public type ILedgerFungible = {
        balance_of: (Account) -> async* Nat;
        transfer: (Icrc1TransferArgs) -> async* Result<Nat, TransferError>;
        transfer_from: (TransferFromArgs) -> async* Result<Nat, TransferFromError>;
        fee: () -> Nat;
        token_symbol: () -> Text;
    };

    public type ILedgerAccount = {
        get_local_balance: () -> Nat;
        pull: (PullArgs) -> async* PullResult;
        transfer: (TransferArgs) -> async* Transfer;
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