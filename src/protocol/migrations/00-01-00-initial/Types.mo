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

    public type DexActor = actor {
        swap_amounts: shared (Text, Nat, Text) -> async SwapAmountsResult;
        swap: shared SwapArgs -> async SwapResult;
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

    public type Timeline<T> = {
        var current: TimedData<T>;
        var history: [TimedData<T>];
    };

    public type TimedData<T> = {
        timestamp: Nat;
        data: T;
    };

    public type VoteRegister = {
        votes: Map<UUID, VoteType>;
        by_origin: Map<Principal, Set<UUID>>;
        by_author: Map<Account, Set.Set<UUID>>;
    };

    public type BallotRegister = {
        ballots: Map<UUID, BallotType>;
        by_account: Map<Account, Set<UUID>>;
    };

    public type VoteType = {
        #YES_NO: Vote<YesNoAggregate, YesNoChoice>;
    };

    public type BallotType = {
        #YES_NO: Ballot<YesNoChoice>;
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
    
    public type Vote<A, B> = {
        vote_id: UUID;
        tx_id: Nat;
        date: Nat;
        origin: Principal;
        aggregate: Timeline<A>;
        ballots: Set<UUID>;
        author: Account;
        var tvl: Nat;
    };

    public type DebtRecord = {
        earned: Float;
        pending: Float;
    };

    public type DebtInfo = {
        id: UUID;
        account: Account;
        amount: Timeline<DebtRecord>;
        var transferred: Nat;
        var transfers: [Transfer];
    };

    public type DebtRegister = {
        debts: Map<UUID, DebtInfo>;
        pending_transfer: Set<UUID>;
    };

    public type Foresight = {
        share: Float;
        reward: Int;
        apr: {
            current: Float;
            potential: Float;
        };
    };

    public type Ballot<B> = {
        ballot_id: UUID;
        vote_id: UUID;
        timestamp: Nat;
        choice: B;
        amount: Nat;
        dissent: Float;
        consent: Timeline<Float>;
        foresight: Timeline<Foresight>;
        tx_id: Nat;
        from: Account;
        decay: Float;
        var hotness: Float;
        var lock: ?LockInfo;
    };

    public type LockInfo = {
        duration_ns: Timeline<Nat>;
        var release_date: Nat;
    };

    public type Transfer = {
        args: Icrc1TransferArgs;
        result: TransferResult;
    };

    public type TransferResult = {
        #ok: TxIndex;
        #err: TransferError;
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

    public type TimerParameters = {
        var interval_s: Nat;
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
        tvl: Timeline<Nat>;
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
        amount_minted: Timeline<Float>;
    };

     type Var<V> = {
        var value: V;
    };

    public type ProtocolAccounts = {
        supply: {
            subaccount: ?Subaccount;
            local_balance: Var<Nat>;
        };
        collateral: {
            subaccount: ?Subaccount;
            local_balance: Var<Nat>;
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

    public type LendingParameters = IndexerParameters and SupplyParameters and BorrowParameters and UtilizationParameters and {
        interest_rate_curve: [CurvePoint];
    };

    public type Owed = {
        index: Index;
        accrued_amount: Float;
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
        accrued_interests: {
            fees: Float;
            supply: Float;
        };
        borrow_index: Index; // growing value, starts at 1.0
        supply_index: Index; // growing value, starts at 1.0
        timestamp: Nat; // last time the rates were updated
    };

    public type DurationScalerParameters = {
        a: Float;  // multiplier parameter
        b: Float;  // logarithmic base parameter
    };

    public type ProtocolParameters = {
        duration_scaler: DurationScalerParameters;
        minimum_ballot_amount: Nat;
        dissent_steepness: Float;
        consent_steepness: Float;
        age_coefficient: Float;
        max_age: Nat;
        // @int: commented out for now, will be implemented later
        //author_fee: Nat;
        //minter_parameters: MinterParameters; 
        timer: TimerParameters;
        decay: {
            half_life: Duration;
            time_init: Nat;
        };
        clock: ClockParameters;
        lending: LendingParameters;
    };

    public type Args = {
        #init: InitArgs;
        #upgrade: UpgradeArgs;
        #downgrade: DowngradeArgs;
        #update: Parameters;
        #none;
    };

    public type Parameters = {
        age_coefficient: Float;
        max_age: Duration;
        ballot_half_life: Duration;
        duration_scaler: DurationScalerParameters;
        minimum_ballot_amount: Nat;
        dissent_steepness: Float;
        consent_steepness: Float;
        timer_interval_s: Nat;
        clock: ClockInitArgs;
        lending: LendingParameters;
    };

    public type InitArgs = {
        canister_ids: {
            supply_ledger: Principal;
            collateral_ledger: Principal;
            dex: Principal;
        };
        parameters: Parameters;
    };
    public type UpgradeArgs = {
    };
    public type DowngradeArgs = {
    };

    public type State = {
        supply_ledger: ICRC1 and ICRC2;
        collateral_ledger: ICRC1 and ICRC2;
        dex: DexActor;
        parameters: ProtocolParameters;
        collateral_price_in_supply: TrackedPrice;
        vote_register: VoteRegister;
        ballot_register: BallotRegister;
        lock_scheduler_state: LockSchedulerState;
        accounts: ProtocolAccounts;
        lending: {
            index: { var value: LendingIndex; };
            register: LendingRegister;
        };
    };
  
};