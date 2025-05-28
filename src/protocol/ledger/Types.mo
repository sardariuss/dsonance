import Types         "../Types";

import Result        "mo:base/Result";

import ICRC1         "mo:icrc1-mo/ICRC1/service";
import ICRC2         "mo:icrc2-mo/ICRC2/service";

module {

    type Result<Ok, Err> = Result.Result<Ok, Err>;

    public type Account = ICRC1.Account;
    public type TxIndex = ICRC1.TxIndex;
    public type Icrc1TransferArgs = ICRC1.TransferArgs;
    public type TransferError = ICRC1.TransferError;
    public type TransferFromError = ICRC2.TransferFromError;
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

    public type SwapPayload = {
        pay_token: Text;
        pay_amount: Nat;
        dex: IDex;
        callback: () -> ();
    };

    public type Swap = {
        against: (ILedgerAccount) -> async* Result<SwapReply, Text>;
    };

    public type PrepareSwapArgs = {
        dex: IDex;
        amount: Nat;
    };

    // Copy/pasted from KongSwap: https://dashboard.internetcomputer.org/canister/2ipq2-uqaaa-aaaar-qailq-cai

    type SwapAmountsTxReply = {
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
    type SwapAmountsReply = {
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
    type SwapAmountsResult = { 
        #Ok: SwapAmountsReply;
        #Err: Text; 
    };

    type ICTransferReply = {
        chain : Text;
        symbol : Text;
        is_send : Bool;
        amount : Nat;
        canister_id : Text;
        block_index : Nat;
    };
    type TransferReply = {
        #IC : ICTransferReply;
    };
    type TransferIdReply = {
        transfer_id : Nat64;
        transfer : TransferReply
    };

    type TxId = {
        BlockIndex : Nat;
        TransactionId : Text;
    };

    type SwapArgs = {
        pay_token: Text;
        pay_amount: Nat;
        pay_tx_id: ?TxId;
        receive_token: Text;
        receive_amount: ?Nat;
        receive_address: ?Text;
        max_slippage: ?Float;
        referred_by: ?Text;
    };

    type SwapTxReply = {
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

    type PriceArgs = {
        pay_token: Text;
        receive_token: Text;
    };

    public type IDex = {
        // swap_amounts(pay_token, pay_amount, receive_token)
        // pay_token, receive_token - format Symbol, Chain.Symbol, CanisterId or Chain.CanisterId ie. ckBTC, IC.ckBTC, or IC.ryjl3-tyaaa-aaaaa-aaaba-cai
        // pay_amount, receive_amount - Nat numbers with corresponding decimal precision as defined in ledger canister
        // - calculates the expected receive_amount and price of the swap
        // - results of swap_amounts() are then pass to swap() for execution
        swap_amounts: (Text, Nat, Text) -> async* SwapAmountsResult;

        // swap()
        // pay_token, receive_token - format Symbol, Chain.Symbol, CanisterId or Chain.CanisterId ie. ckBTC, IC.ckBTC, or IC.ryjl3-tyaaa-aaaaa-aaaba-cai
        // pay_amount, receive_amount - Nat numbers with corresponding decimal precision as defined in ledger canister
        // - swaps pay_amount of pay_token into receive_amount of receive_token
        // - swap() has 2 variations:
        //   1) icrc2_approve + icrc2_transfer_from - user must icrc2_approve the pay_amount+gas of pay_token and then call swap() where the canister will then icrc2_transfer_from
        //   2) icrc1_transfer - user must icrc1_transfer the pay_amount of pay_token and then call swap() with the block index
        swap: SwapArgs -> async* SwapResult;

        // @todo: very temporary function
        last_price: PriceArgs -> Float;
    };

    public type ILedgerFungible = {
        icrc1_transfer: (Icrc1TransferArgs) -> async* Result<TxIndex, TransferError>;
        icrc2_transfer_from: (TransferFromArgs) -> async* Result<TxIndex, TransferFromError>;
    };

    public type ILedgerAccount = {
        get_local_balance: () -> Nat;
        token_symbol: () -> Text;
        pull: (PullArgs) -> async* PullResult;
        transfer: (TransferArgs) -> async* Transfer;
        perform_swap: (SwapPayload) -> async* Result<SwapReply, Text>;
        swap: (PrepareSwapArgs) -> Swap;
    };

};