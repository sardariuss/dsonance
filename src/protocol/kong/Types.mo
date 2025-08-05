
module {

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

    public type SendArgs = {
        token : Text;
        amount : Nat;
        to_address : Text;
    };

    public type SendReply = {
        tx_id : Nat64;
        request_id : Nat64;
        status : Text;
        chain : Text;
        symbol : Text;
        amount : Nat;
        to_address : Text;
        ts : Nat64;
    };

    public type SendResult = {
        #Ok : SendReply;
        #Err : Text;
    };

    public type KongBackendActor = actor {
        // swap_amounts(pay_token, pay_amount, receive_token)
        // pay_token, receive_token - format Symbol, Chain.Symbol, CanisterId or Chain.CanisterId ie. ckBTC, IC.ckBTC, or IC.ryjl3-tyaaa-aaaaa-aaaba-cai
        // pay_amount, receive_amount - Nat numbers with corresponding decimal precision as defined in ledger canister
        // - calculates the expected receive_amount and price of the swap
        // - results of swap_amounts() are then pass to swap() for execution
        // Note: mid_price returned by swap_amounts() is in tokens, not units
        //      ie. if pay_token is ckBTC (8 decimals) and receive_token is ckUSDT (6 decimals), mid_price is in "USDT per BTC" rather than "micro-USDT per satoshi"
        swap_amounts: shared (Text, Nat, Text) -> async SwapAmountsResult;

        // swap()
        // pay_token, receive_token - format Symbol, Chain.Symbol, CanisterId or Chain.CanisterId ie. ckBTC, IC.ckBTC, or IC.ryjl3-tyaaa-aaaaa-aaaba-cai
        // pay_amount, receive_amount - Nat numbers with corresponding decimal precision as defined in ledger canister
        // - swaps pay_amount of pay_token into receive_amount of receive_token
        // - swap() has 2 variations:
        //   1) icrc2_approve + icrc2_transfer_from - user must icrc2_approve the pay_amount+gas of pay_token and then call swap() where the canister will then icrc2_transfer_from
        //   2) icrc1_transfer - user must icrc1_transfer the pay_amount of pay_token and then call swap() with the block index
        swap: shared SwapArgs -> async SwapResult;

        // send LP tokens to another user
        send: shared SendArgs -> async SendResult;
    };

    // Copy/pasted from KongSwap: https://dashboard.internetcomputer.org/canister/cbefx-hqaaa-aaaar-qakrq-cai

    public type AddPoolArgs = {
        token_0 : Text;
        amount_0 : Nat;
        tx_id_0 : ?TxId;
        token_1 : Text;
        amount_1 : Nat;
        tx_id_1 : ?TxId;
        lp_fee_bps : ?Nat8;
    };

    public type AddPoolReply = {
        tx_id : Nat64;
        pool_id : Nat32;
        request_id : Nat64;
        status : Text;
        name : Text;
        symbol : Text;
        chain_0 : Text;
        address_0 : Text;
        symbol_0 : Text;
        amount_0 : Nat;
        chain_1 : Text;
        address_1 : Text;
        symbol_1 : Text;
        amount_1 : Nat;
        lp_fee_bps : Nat8;
        lp_token_symbol : Text;
        add_lp_token_amount : Nat;
        transfer_ids : [TransferIdReply];
        claim_ids : [Nat64];
        is_removed : Bool;
        ts : Nat64;
    };

    public type AddLiquidityArgs = {
        token_0 : Text;
        amount_0 : Nat;
        tx_id_0 : ?TxId;
        token_1 : Text;
        amount_1 : Nat;
        tx_id_1 : ?TxId;
    };

    public type AddLiquidityReply = {
        tx_id : Nat64;
        request_id : Nat64;
        status : Text;
        symbol : Text;
        chain_0 : Text;
        address_0 : Text;
        symbol_0 : Text;
        amount_0 : Nat;
        chain_1 : Text;
        address_1 : Text;
        symbol_1 : Text;
        amount_1 : Nat;
        add_lp_token_amount : Nat;
        transfer_ids : [TransferIdReply];
        claim_ids : [Nat64];
        ts : Nat64;
    };

    public type RemoveLiquidityArgs = {
        token_0 : Text;
        token_1 : Text;
        remove_lp_token_amount : Nat;
    };

    public type RemoveLiquidityReply = {
        tx_id : Nat64;
        request_id : Nat64;
        status : Text;
        symbol : Text;
        chain_0 : Text;
        address_0 : Text;
        symbol_0 : Text;
        amount_0 : Nat;
        lp_fee_0 : Nat;
        chain_1 : Text;
        address_1 : Text;
        symbol_1 : Text;
        amount_1 : Nat;
        lp_fee_1 : Nat;
        remove_lp_token_amount : Nat;
        transfer_ids : [TransferIdReply];
        claim_ids : [Nat64];
        ts : Nat64;
    };

    public type TxsReply = {
        #AddPool : AddPoolReply;
        #AddLiquidity : AddLiquidityReply;
        #RemoveLiquidity : RemoveLiquidityReply;
        #Swap : SwapReply;
    };

    public type TxsResult = {
        #Ok : [TxsReply];
        #Err : Text;
    };

    public type KongDataActor = actor {
        // txs(opt principal_id, opt tx_id, opt token_id, opt num_txs) - returns transactions filtered by principal id, transaction id or token
        txs : shared (?Text, ?Nat64, ?Nat32, ?Nat16) -> async (TxsResult);
    };

};