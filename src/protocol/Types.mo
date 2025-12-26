import Float "mo:base/Float";
import Result "mo:base/Result";

import Types "migrations/00-02-00-renamings/Types";

import Map "mo:map/Map";

module {

    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type Iter<T> = Map.Iter<T>;

    // MIGRATION TYPES

    public type Account                  = Types.Account;
    public type Subaccount               = Types.Subaccount;
    public type SupportedStandard        = Types.SupportedStandard;
    public type Value                    = Types.Value;
    public type Balance                  = Types.Balance;
    public type Timestamp                = Types.Timestamp;
    public type TimeError                = Types.TimeError;
    public type TxIndex                  = Types.TxIndex;
    public type ICRC1                    = Types.ICRC1;
    public type ApproveArgs              = Types.ApproveArgs;
    public type ApproveError             = Types.ApproveError;
    public type TransferFromError        = Types.TransferFromError;
    public type TransferFromArgs         = Types.TransferFromArgs;
    public type AllowanceArgs            = Types.AllowanceArgs;
    public type Allowance                = Types.Allowance;
    public type ICRC2                    = Types.ICRC2;
    public type PoolRegister             = Types.PoolRegister;
    public type PoolType                 = Types.PoolType;
    public type YesNoAggregate           = Types.YesNoAggregate;
    public type Decayed                  = Types.Decayed;
    public type YesNoChoice              = Types.YesNoChoice;
    public type TimedData<T>             = Types.TimedData<T>;
    public type RollingTimeline<T>       = Types.RollingTimeline<T>;
    public type Timeline<T>              = Types.Timeline<T>;
    public type Pool<A, C>               = Types.Pool<A, C>;
    public type LockInfo                 = Types.LockInfo;
    public type Position<C>              = Types.Position<C>;
    public type Duration                 = Types.Duration;
    public type State                    = Types.State;
    public type ClockParameters          = Types.ClockParameters;
    public type UUID                     = Types.UUID;
    public type Lock                     = Types.Lock;
    public type DebtInfo                 = Types.DebtInfo;
    public type Transfer                 = Types.Transfer;
    public type TransferResult           = Types.TransferResult;
    public type PositionType             = Types.PositionType;
    public type LimitOrder<C>            = Types.LimitOrder<C>;
    public type LimitOrderBTreeKey       = Types.LimitOrderBTreeKey;
    public type LimitOrderType           = Types.LimitOrderType;
    public type PositionMap              = Types.PositionMap;
    public type LimitOrderMap            = Types.LimitOrderMap;
    public type Parameters               = Types.Parameters;
    public type LendingParameters        = Types.LendingParameters;
    public type DurationScalerParameters = Types.DurationScalerParameters;
    public type Foresight                = Types.Foresight;
    public type Register<T>              = Types.Register<T>;
    public type DebtRegister             = Types.DebtRegister;
    public type DebtRecord               = Types.DebtRecord;
    public type MinterParameters         = Types.MinterParameters;
    public type MiningParameters         = Types.MiningParameters;
    public type MiningTracker            = Types.MiningTracker;
    public type LockSchedulerState       = Types.LockSchedulerState;
    public type YieldState               = Types.YieldState;
    public type TransferError            = Types.TransferError;
    public type Index                    = Types.Index;
    public type Utilization              = Types.Utilization;
    public type LendingIndex             = Types.LendingIndex;
    public type ForesightParameters      = Types.ForesightParameters;

    // CANISTER ARGS

    public type QueryDirection = {
        #forward;
        #backward;
    };

    public type NewPoolArgs = {
        account: Account;
        type_enum: PoolTypeEnum;
        id: UUID;
    };

    public type GetPoolsArgs = {
        origin: Principal;
        previous: ?UUID;
        limit: Nat;
        direction: QueryDirection;
    };

    public type GetPoolsByAuthorArgs = {
        author: Account;
        previous: ?UUID;
        limit: Nat;
        direction: QueryDirection;
    };

    public type GetPositionArgs = {
        account: Account;
        previous: ?UUID;
        limit: Nat;
        filter_active: Bool;
        direction: QueryDirection;
    };

    public type GetLimitOrderArgs = {
        account: Account;
        previous: ?UUID;
        limit: Nat;
        direction: QueryDirection;
    };

    public type FindPoolArgs = {
        pool_id: UUID;
    };

    public type AmountOrigin = {
        #FROM_WALLET;
        #FROM_SUPPLY: { max_slippage_amount: Nat; };
    };

    public type PutPositionArgs = {
        id: UUID;
        pool_id: UUID;
        choice_type: ChoiceType;
        from_subaccount: ?Blob;
        amount: Nat;
        origin: AmountOrigin;
    };

    public type PutPositionPreview = PutPositionArgs and {
        with_supply_apy_impact: Bool;
    };

    public type PreviewLimitOrderArgs = {
        order_id: UUID;
        pool_id: UUID;
        choice_type: ChoiceType;
        from: Account;
        amount: Nat;
        limit_consensus: Float;
    };

    public type PutLimitOrderArgs = PreviewLimitOrderArgs and {
        from_origin: AmountOrigin;
    };

    public type FindPositionArgs = {
        pool_id: UUID;
        position_id: UUID;
    };

    public type UserSupply = {
        amount: Nat;
        apr: Float;
    };

    // SHARED TYPES

    public type SYieldState = {
        tvl: Nat;
        apr: Float;
        interest: {
            earned: Float;
            time_last_update: Nat;
        };
    };

    public type SPoolType = {
        #YES_NO: SPool<YesNoAggregate, YesNoChoice>;
    };

    public type SPositionType = {
        #YES_NO: SPosition<YesNoChoice>;
    };

    public type SDebtInfo = {
        id: UUID;
        account: Account;
        amount: SRollingTimeline<DebtRecord>;
        transferred: Nat;
        transfers: [Transfer];
    };

    public type SRollingTimeline<T> = {
        current: TimedData<T>;
        history: [TimedData<T>];
        maxSize: Nat;
        minIntervalNs: Nat;
    };

    public type STimeline<T> = {
        current: TimedData<T>;
        history: [TimedData<T>];
        minIntervalNs: Nat;
    };

    public type SPosition<C> = {
        position_id: UUID;
        pool_id: UUID;
        timestamp: Nat;
        choice: C;
        amount: Nat;
        dissent: Float;
        consent: Float;
        tx_id: Nat;
        supply_index: Float;
        from: Account;
        decay: Float;
        foresight: Foresight;
        hotness: Float;
        lock: ?SLockInfo;
    };

    public type SLockInfo = {
        duration_ns: SRollingTimeline<Nat>;
        release_date: Nat;
    };

    public type SPool<A, C> = {
        pool_id: UUID;
        date: Nat;
        origin: Principal;
        aggregate: SRollingTimeline<A>;
        tvl: Int;
    };

    public type SClockParameters = {
        #REAL;
        #SIMULATED: {
            time_ref: Nat;
            offset: Duration;
            dilation_factor: Float;
        };
    };

    public type SMinterParameters = {
        contribution_per_day: Nat;
        author_share: Float;
        time_last_mint: Nat;
    };

    public type SParameters = {
        foresight: {
            dissent_steepness: Float;
            consent_steepness: Float;
        };
        duration_scaler: DurationScalerParameters;
        minimum_position_amount: Nat;
        position_half_life: Duration;
        clock: SClockParameters;
        lending: LendingParameters;
        mining: {
            emission_half_life_s: Float;
            emission_total_amount_e8s: Nat;
            borrowers_share: Float;
        };
        twap_config: {
            window_duration: Duration;
            max_observations: Nat;
        };
    };

    // CUSTOM TYPES

    public type ProtocolInfo = {
        current_time: Nat;
        genesis_time: Nat;
    };

    public type LockEvent = {
        #LOCK_ADDED: Lock;
        #LOCK_REMOVED: Lock;
    };

    public type UpdateAggregate<A, C> = ({aggregate: A; choice: C; amount: Nat; time: Nat;}) -> A;
    public type ComputeDissent<A, C> = ({aggregate: A; choice: C; amount: Nat; time: Nat;}) -> Float;
    public type ComputeConsent<A, C> = ({aggregate: A; choice: C; time: Nat;}) -> Float;

    public type PositionAggregatorOutcome<A> = {
        aggregate: {
            update: A;
        };
        position: {
            dissent: Float;
            consent: Float;
        };
    };

    public type AggregateHistoryType = {
        #YES_NO: [TimedData<YesNoAggregate>];
    };

    public type ChoiceType = {
        #YES_NO: YesNoChoice;
    };

    public type PoolTypeEnum = {
        #YES_NO;
    };

    public type YesNoPosition = Position<YesNoChoice>;
    public type YesNoPool = Pool<YesNoAggregate, YesNoChoice>;

    // RESULT/ERROR TYPES

    public type PutPositionSuccess = {
        new: PositionType;
        previous: [PositionType];
    };

    public type SPutPositionSuccess = {
        new: SPositionType;
        previous: [SPositionType];
    };

    public type PutLimitOrderSuccess = {
        matching: ?PutPositionSuccess;
        order: ?LimitOrderType;
    };

    public type SPutLimitOrderSuccess = {
        matching: ?SPutPositionSuccess;
        order: ?LimitOrderType;
    };

    public type PoolNotFoundError        = { #PoolNotFound: { pool_id: UUID; }; };
    public type InsuficientAmountError   = { #InsufficientAmount: { amount: Nat; minimum: Nat; }; };
    public type NewPoolError             = { #PoolAlreadyExists: { pool_id: UUID; }; } or TransferFromError;
    public type PositionAlreadyExistsError = { #PositionAlreadyExists: { position_id: UUID; }; };
    public type PutPositionError           = PoolNotFoundError or InsuficientAmountError or PositionAlreadyExistsError or TransferFromError;
    public type PutPositionResult          = Result<SPutPositionSuccess, Text>;
    public type PutLimitOrderResult        = Result<SPutLimitOrderSuccess, Text>;
    public type NewPoolResult            = Result<PoolType, Text>;
    public type SNewPoolResult           = Result<SPoolType, Text>;

};