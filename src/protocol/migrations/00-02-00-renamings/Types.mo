import Error "mo:base/Error";

import Map   "mo:map/Map";
import Set   "mo:map/Set";
import BTree "mo:stableheapbtreemap/BTree";

// please do not import any types from your project outside migrations folder here
// it can lead to bugs when you change those types later, because migration types should not be changed
// you should also avoid importing these types anywhere in your project directly from here
// use MigrationTypes.Current property instead
module {

    type Map<K, V> = Map.Map<K, V>;
    type Set<K> = Set.Set<K>;
    type BTree<K, V> = BTree.BTree<K, V>;

    // From ICRC1    

    public type Account = {
        owner : Principal;
        subaccount : ?Subaccount;
    };

    public type Subaccount = Blob;

    public type SupportedStandard = {
        name : Text;
        url : Text;
    };

    public type Value = { #Nat : Nat; #Int : Int; #Blob : Blob; #Text : Text; #Array : [Value]; #Map: [(Text, Value)] };

    public type Balance = Nat;

    public type Timestamp = Nat64;

    public type TimeError = {
        #TooOld;
        #CreatedInFuture : { ledger_time : Timestamp };
    };

    public type TxIndex = Nat;

    public type Icrc1TransferError = TimeError or {
        #BadFee : { expected_fee : Balance };
        #BadBurn : { min_burn_amount : Balance };
        #InsufficientFunds : { balance : Balance };
        #Duplicate : { duplicate_of : TxIndex };
        #TemporarilyUnavailable;
        #GenericError : { error_code : Nat; message : Text };
    };
    
    public type Icrc1TransferResult = {
        #Ok : TxIndex;
        #Err : Icrc1TransferError;
    };

    public type Icrc1TransferArgs = {
        from_subaccount : ?Subaccount;
        to : Account;
        amount : Balance;
        fee : ?Balance;
        memo : ?Blob;

        /// The time at which the transaction was created.
        /// If this is set, the canister will check for duplicate transactions and reject them.
        created_at_time : ?Nat64;
    };


    public type ICRC1 = actor {
        icrc1_balance_of : shared query Account -> async Nat;
        icrc1_decimals : shared query () -> async Nat8;
        icrc1_fee : shared query () -> async Nat;
        icrc1_metadata : shared query () -> async [(Text, Value)];
        icrc1_minting_account : shared query () -> async ?Account;
        icrc1_name : shared query () -> async Text;
        icrc1_supported_standards : shared query () -> async [SupportedStandard];
        icrc1_symbol : shared query () -> async Text;
        icrc1_total_supply : shared query () -> async Nat;
        icrc1_transfer : shared Icrc1TransferArgs -> async Icrc1TransferResult;
    };

    // From ICRC2

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
        #BadFee :  { expected_fee : Nat };
        // The caller does not have enough funds to pay the approval fee.
        #InsufficientFunds :  { balance : Nat };
        // The caller specified the [expected_allowance] field, and the current
        // allowance did not match the given value.
        #AllowanceChanged :  { current_allowance : Nat };
        // The approval request expired before the ledger had a chance to apply it.
        #Expired :  { ledger_time : Nat64; };
        #TooOld;
        #CreatedInFuture:  { ledger_time : Nat64 };
        #Duplicate :  { duplicate_of : Nat };
        #TemporarilyUnavailable;
        #GenericError :  { error_code : Nat; message : Text };
    };

    public type TransferFromError =  {
        #BadFee :  { expected_fee : Nat };
        #BadBurn :  { min_burn_amount : Nat };
        // The [from] account does not hold enough funds for the transfer.
        #InsufficientFunds :  { balance : Nat };
        // The caller exceeded its allowance.
        #InsufficientAllowance :  { allowance : Nat };
        #TooOld;
        #CreatedInFuture:  { ledger_time : Nat64 };
        #Duplicate :  { duplicate_of : Nat };
        #TemporarilyUnavailable;
        #GenericError :  { error_code : Nat; message : Text };
    };

    public type TransferFromArgs =  {
        spender_subaccount : ?Blob;
        from : Account;
        to : Account;
        amount : Nat;
        fee : ?Nat;
        memo : ?Blob;
        created_at_time : ?Nat64;
    };

    public type AllowanceArgs =  {
        account : Account;
        spender : Account;
    };

    public type Allowance =  {
        allowance : Nat;
        expires_at : ?Nat64;
    };

    public type ICRC2 = actor {
        icrc2_approve : (ApproveArgs) -> async ({ #Ok : Nat; #Err : ApproveError });
        icrc2_transfer_from : (TransferFromArgs) -> async  { #Ok : Nat; #Err : TransferFromError };
        icrc2_allowance : query (AllowanceArgs) -> async (Allowance);
    };

    // FROM LEDGER TYPES

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
        swap_amounts: shared (Text, Nat, Text) -> async SwapAmountsResult;
        swap: shared SwapArgs -> async SwapResult;
        send: shared SendArgs -> async SendResult;
    };

    // === Types from the XRC IDL ===

    public type AssetClass = {
        #Cryptocurrency;
        #FiatCurrency;
    };

    public type Asset = {
        symbol : Text;
        class_ : AssetClass;
    };

    public type GetExchangeRateRequest = {
        base_asset : Asset;
        quote_asset : Asset;
        timestamp : ?Nat64;
    };

    public type ExchangeRateMetadata = {
        decimals : Nat32;
        base_asset_num_received_rates : Nat64;
        base_asset_num_queried_sources : Nat64;
        quote_asset_num_received_rates : Nat64;
        quote_asset_num_queried_sources : Nat64;
        standard_deviation : Nat64;
        forex_timestamp : ?Nat64;
    };

    public type ExchangeRate = {
        base_asset : Asset;
        quote_asset : Asset;
        timestamp : Nat64;
        rate : Nat64;
        metadata : ExchangeRateMetadata;
    };

    public type ExchangeRateError = {
        #AnonymousPrincipalNotAllowed;
        #Pending;
        #CryptoBaseAssetNotFound;
        #CryptoQuoteAssetNotFound;
        #StablecoinRateNotFound;
        #StablecoinRateTooFewRates;
        #StablecoinRateZeroRate;
        #ForexInvalidTimestamp;
        #ForexBaseAssetNotFound;
        #ForexQuoteAssetNotFound;
        #ForexAssetsNotFound;
        #RateLimited;
        #NotEnoughCycles;
        #FailedToAcceptCycles;
        #InconsistentRatesReceived;
        #Other : { code : Nat32; description : Text };
    };

    public type GetExchangeRateResult = {
        #Ok : ExchangeRate;
        #Err : ExchangeRateError;
    };

    public type XrcActor = actor {
        get_exchange_rate : shared query (GetExchangeRateRequest) -> async (GetExchangeRateResult);
    };

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
        txs : shared (?Text, ?Nat64, ?Nat32, ?Nat16) -> async (TxsResult);
    };

    public type TrackedPrice = {
        var value: ?Float;
    };

    // FROM PROTOCOL ITSELF

    public type UUID = Text;

    public type Register<T> = {
        var index: Nat;
        map: Map.Map<Nat, T>;
    };

    public type TimedData<T> = {
        timestamp: Nat;
        data: T;
    };

    public type Timeline<T> = {
        var current: TimedData<T>;
        var history: [TimedData<T>];
        var lastCheckpointTimestamp: Nat;
        minIntervalNs: Nat;
    };

    public type RollingTimeline<T> = {
        var current: TimedData<T>;
        history: [var ?TimedData<T>];
        var lastCheckpointTimestamp: Nat;
        var index: Nat;
        maxSize: Nat;
        minIntervalNs: Nat;
    };

    public type PoolRegister = {
        pools: Map<UUID, PoolType>;
        by_origin: Map<Principal, Set<UUID>>;
        by_author: Map<Account, Set.Set<UUID>>;
    };

    public type PositionRegister = {
        positions: Map<UUID, PositionType>;
        by_account: Map<Account, Set<UUID>>;
    };

    public type PoolType = {
        #YES_NO: Pool<YesNoAggregate, YesNoChoice>;
    };

    public type PositionType = {
        #YES_NO: Position<YesNoChoice>;
    };

    public type YesNoAggregate = {
        total_yes: Nat;
        current_yes: Decayed;
        total_no: Nat;
        current_no: Decayed;
    };

    public type Decayed = {
        #DECAYED: Float;
    };

    public type YesNoChoice = {
        #YES;
        #NO;
    };

    public type LimitOrder<C> = {
        order_id: UUID;
        account: Account;
        choice: C;
        limit_dissent: Float;
        var raw_amount: Nat;
        supply_index: Float;
        tx_id: Nat;
        timestamp: Nat;
    };

    public type LimitOrderBTreeKey = {
        limit_dissent: Float;
        timestamp: Nat;
    };
    
    public type Pool<A, C> = {
        pool_id: UUID;
        tx_id: Nat;
        date: Nat;
        origin: Principal;
        aggregate: RollingTimeline<A>;
        descending_orders: Map<C, BTree<LimitOrderBTreeKey, UUID>>;
        positions: Set<UUID>;
        author: Account;
        var tvl: Int;
    };

    public type DebtRecord = {
        earned: Float;
        pending: Float;
    };

    public type DebtInfo = {
        id: UUID;
        account: Account;
        amount: RollingTimeline<DebtRecord>;
        var transferred: Nat;
        var transfers: [Transfer];
    };

    public type DebtRegister = {
        debts: Map<UUID, DebtInfo>;
        pending_transfer: Set<UUID>;
    };

    public type Foresight = {
        reward: Int;
        apr: {
            current: Float;
            potential: Float;
        };
    };

    public type Position<C> = {
        position_id: UUID;
        pool_id: UUID;
        timestamp: Nat;
        choice: C;
        amount: Nat;
        dissent: Float;
        consent: RollingTimeline<Float>;
        tx_id: Nat;
        from: Account;
        decay: Float;
        var foresight: Foresight;
        var hotness: Float;
        var lock: ?LockInfo;
    };

    public type LockInfo = {
        duration_ns: RollingTimeline<Nat>;
        var release_date: Nat;
    };

    public type Transfer = {
        args: Icrc1TransferArgs;
        result: TransferResult;
    };

    public type ForesightParameters = {
        dissent_steepness: Float;
        consent_steepness: Float;
    };

    public type TransferResult = {
        #ok: TxIndex;
        #err: Text;
    };

    public type TransferError = Icrc1TransferError or { 
        #Trapped : { error_code: Error.ErrorCode; }
    };

    public type Duration = {
        #YEARS: Nat;
        #DAYS: Nat;
        #HOURS: Nat;
        #MINUTES: Nat;
        #SECONDS: Nat;
        #NS: Nat;
    };

    public type ClockInitArgs = {
        #REAL;
        #SIMULATED: {
            dilation_factor: Float;
        };
    };

    public type ClockParameters = {
        #REAL;
        #SIMULATED: {
            var time_ref: Nat;
            var offset_ns: Nat;
            var dilation_factor: Float;
        };
    };

    public type Lock = {
        release_date: Nat;
        amount: Nat;
        id: UUID;
    };

    public type LockSchedulerState = {
        btree: BTree<Lock, ()>;
        map: Map<Text, Lock>;
    };

    public type YieldState = {
        var tvl: Nat;
        var apr: Float;
        interest: {
            var earned: Float;
            var time_last_update: Nat;
        };
    };

    public type MinterArgs = {
        contribution_per_day: Nat;
        author_share: Float;
    };

    public type MinterParameters = {
        var contribution_per_day: Nat;
        var author_share: Float;
        var time_last_mint: Nat;
    };

    public type MiningParameters = {
        emission_half_life: Duration;
        emission_total_amount_e8s: Nat;
        borrowers_share: Float;
    };

    public type MiningTracker = {
        claimed: Nat;
        allocated: Nat;
    };

     type Var<V> = {
        var value: V;
    };

    public type ProtocolAccounts = {
        supply: {
            subaccount: ?Subaccount;
            fees_subaccount: Subaccount;
            unclaimed_fees: {
                var value: Float;
            };
        };
        collateral: {
            subaccount: ?Subaccount;
        };
    };

    // FROM LENDING

    public type CurvePoint = {
        utilization: Float; // Utilization ratio (0.0 to 1.0)
        rate: Float; // Annual Percentage Rate (APR) at this utilization (e.g., 0.05 for 5%)
    };

    public type UtilizationParameters = {
        reserve_liquidity: Float; // portion of supply reserved (0.0 to 1.0, e.g., 0.1 for 10%), to mitigate illiquidity risk
    };

    public type IndexerParameters = {
        lending_fee_ratio: Float; // portion of the supply interest reserved as a fee for the protocol
    };

    public type SupplyParameters = {
        supply_cap: Nat;
    };

    public type BorrowParameters = {
        borrow_cap: Nat;
        target_ltv: Float; // ratio, between 0 and 1, e.g. 0.75
        max_ltv: Float; // ratio, between 0 and 1, e.g. 0.75
        liquidation_threshold: Float; // ratio, between 0 and 1, e.g. 0.85
        liquidation_penalty: Float; // ratio, between 0 and 1, e.g. 0.10
        close_factor: Float; // ratio, between 0 and 1, e.g. 0.50, used
                              // to determine how much of the borrow can be repaid
                              // in a single transaction, e.g. 50% of the borrow
                              // can be repaid in a single transaction
        max_slippage: Float;
    };

    public type TWAPConfig = {
        window_duration_ns: Nat;
        max_observations: Nat;
    };

    public type LendingParameters = IndexerParameters and SupplyParameters and BorrowParameters and UtilizationParameters and {
        interest_rate_curve: [CurvePoint];
    };

    public type Owed = {
        index: Index;
        accrued_amount: Float;
        from_interests: Float;
    };

    public type Borrow = {
        // original borrowed, unaffected by index growth
        // used to scale linearly based on repayment proportion
        raw_amount: Float; 
        owed: Owed;
    };

    public type Collateral = {
        amount: Nat;
    };

    public type BorrowPositionTx = {
        #COLLATERAL_PROVIDED: TxIndex;
        #COLLATERAL_WITHDRAWNED: TxIndex;
        #SUPPLY_BORROWED: TxIndex;
        #SUPPLY_REPAID: TxIndex;
    };

    public type BorrowPosition = {
        account: Account;
        collateral: Collateral;
        borrow: ?Borrow;
        tx: [BorrowPositionTx];
    };

    public type Index = {
        timestamp: Nat;
        value: Float;
    };

    public type SupplyInput = {
        id: Text;
        account: Account;
        supplied: Nat;
    };

    public type SupplyPosition = SupplyInput and {
        tx: TxIndex;
        index: Float;
    };

    public type Withdrawal = {
        id: Text;
        account: Account;
        supplied: Nat;
        due: Nat;
        var transferred: Nat;
        var transfers: [TransferResult]; // TODO: need to limit the number of transfers
    };

    public type BorrowRegister = {
        borrow_positions: Map.Map<Account, BorrowPosition>;
    };

    public type SupplyRegister = {
        supply_positions: Map.Map<Text, SupplyPosition>;
    };

    public type WithdrawalRegister = {
        withdrawals: Map.Map<Text, Withdrawal>;
        withdraw_queue: Set.Set<Text>;
    };

    public type LendingRegister = BorrowRegister and SupplyRegister and WithdrawalRegister;

    public type Utilization = {
        raw_supplied: Float;
        raw_borrowed: Float;
        ratio: Float; // Utilization ratio (0.0 to 1.0)
    };

    public type LendingIndex = {
        utilization: Utilization;
        borrow_rate: Float; // borrow rate (ratio)
        supply_rate: Float; // supply rate (ratio)
        borrow_index: Index; // growing value, starts at 1.0
        supply_index: Index; // growing value, starts at 1.0
        timestamp: Nat; // last time the rates were updated
    };

    public type DurationScalerParameters = {
        a: Float;  // multiplier parameter
        b: Float;  // logarithmic base parameter
    };

    public type Parameters = {
        foresight: ForesightParameters;
        duration_scaler: DurationScalerParameters;
        minimum_position_amount: Nat;
        mining: {
            emission_half_life_s: Float;
            emission_total_amount_e8s: Nat;
            borrowers_share: Float;
        };
        timer_interval_s: Nat;
        position_half_life_ns: Nat;
        clock: ClockParameters;
        lending: LendingParameters;
        twap_config: TWAPConfig;
    };

    public type Args = {
        #init: InitArgs;
        #upgrade: UpgradeArgs;
        #downgrade: DowngradeArgs;
        #update: InitParameters;
        #none;
    };

    public type InitParameters = {
        position_half_life: Duration;
        duration_scaler: DurationScalerParameters;
        minimum_position_amount: Nat;
        foresight: {
            dissent_steepness: Float;
            consent_steepness: Float;
        };
        mining: MiningParameters;
        timer_interval_s: Nat; // Use duration instead
        clock: ClockInitArgs;
        lending: LendingParameters;
        twap_config: {
            window_duration: Duration;
            max_observations: Nat;
        };
    };

    public type InitArgs = {
        canister_ids: {
            supply_ledger: Principal;
            collateral_ledger: Principal;
            participation_ledger: Principal;
            kong_backend: Principal;
            xrc: Principal;
        };
        parameters: InitParameters;
    };
    public type UpgradeArgs = {
    };
    public type DowngradeArgs = {
    };

    public type State = {
        genesis_time: Nat;
        supply_ledger: ICRC1 and ICRC2;
        collateral_ledger: ICRC1 and ICRC2;
        participation_ledger: ICRC1 and ICRC2;
        kong_backend: KongBackendActor;
        xrc: XrcActor;
        parameters: Parameters;
        collateral_twap_price: {
            var spot_price: ?Float;
            var observations: [{ timestamp: Int; price: Float; }];
            var twap_cache: ?Float;
            var last_twap_calculation: Int;
        };
        pool_register: PoolRegister;
        position_register: PositionRegister;
        lock_scheduler_state: LockSchedulerState;
        accounts: ProtocolAccounts;
        lending: {
            index: Timeline<LendingIndex>;
            register: LendingRegister;
        };
        mining: {
            var last_mint_timestamp: Nat;
            tracking: Map<Account, MiningTracker>;
            total_allocated: RollingTimeline<Nat>;
            total_claimed: RollingTimeline<Nat>;
        };
    };
  
};