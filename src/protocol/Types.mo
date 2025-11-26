import Float "mo:base/Float";
import Result "mo:base/Result";

import Types "migrations/Types";

import Map "mo:map/Map";

module {

    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type Iter<T> = Map.Iter<T>;

    // MIGRATION TYPES

    public type Account                  = Types.Current.Account;
    public type Subaccount               = Types.Current.Subaccount;
    public type SupportedStandard        = Types.Current.SupportedStandard;
    public type Value                    = Types.Current.Value;
    public type Balance                  = Types.Current.Balance;
    public type Timestamp                = Types.Current.Timestamp;
    public type TimeError                = Types.Current.TimeError;
    public type TxIndex                  = Types.Current.TxIndex;
    public type ICRC1                    = Types.Current.ICRC1;
    public type ApproveArgs              = Types.Current.ApproveArgs;
    public type ApproveError             = Types.Current.ApproveError;
    public type TransferFromError        = Types.Current.TransferFromError;
    public type TransferFromArgs         = Types.Current.TransferFromArgs;
    public type AllowanceArgs            = Types.Current.AllowanceArgs;
    public type Allowance                = Types.Current.Allowance;
    public type ICRC2                    = Types.Current.ICRC2;
    public type PoolRegister             = Types.Current.PoolRegister;
    public type PoolType                 = Types.Current.PoolType;
    public type YesNoAggregate           = Types.Current.YesNoAggregate;
    public type Decayed                  = Types.Current.Decayed;
    public type YesNoChoice              = Types.Current.YesNoChoice;
    public type TimedData<T>             = Types.Current.TimedData<T>;
    public type RollingTimeline<T>       = Types.Current.RollingTimeline<T>;
    public type Timeline<T>              = Types.Current.Timeline<T>;
    public type Pool<A, C>               = Types.Current.Pool<A, C>;
    public type LockInfo                 = Types.Current.LockInfo;
    public type Position<C>              = Types.Current.Position<C>;
    public type Duration                 = Types.Current.Duration;
    public type State                    = Types.Current.State;
    public type ClockParameters          = Types.Current.ClockParameters;
    public type UUID                     = Types.Current.UUID;
    public type Lock                     = Types.Current.Lock;
    public type DebtInfo                 = Types.Current.DebtInfo;
    public type Transfer                 = Types.Current.Transfer;
    public type TransferResult           = Types.Current.TransferResult;
    public type PositionType             = Types.Current.PositionType;
    public type LimitOrder<C>            = Types.Current.LimitOrder<C>;
    public type LimitOrderBTreeKey       = Types.Current.LimitOrderBTreeKey;
    public type PositionRegister         = Types.Current.PositionRegister;
    public type Parameters               = Types.Current.Parameters;
    public type LendingParameters        = Types.Current.LendingParameters;
    public type DurationScalerParameters = Types.Current.DurationScalerParameters;
    public type Foresight                = Types.Current.Foresight;
    public type Register<T>              = Types.Current.Register<T>;
    public type DebtRegister             = Types.Current.DebtRegister;
    public type DebtRecord               = Types.Current.DebtRecord;
    public type MinterParameters         = Types.Current.MinterParameters;
    public type MiningParameters         = Types.Current.MiningParameters;
    public type MiningTracker            = Types.Current.MiningTracker;
    public type LockSchedulerState       = Types.Current.LockSchedulerState;
    public type YieldState               = Types.Current.YieldState;
    public type TransferError            = Types.Current.TransferError;
    public type Index                    = Types.Current.Index;
    public type Utilization              = Types.Current.Utilization;
    public type LendingIndex             = Types.Current.LendingIndex;
    public type ForesightParameters      = Types.Current.ForesightParameters;

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

    public type FindPoolArgs = {
        pool_id: UUID;
    };

    public type PutPositionArgs = {
        id: UUID;
        pool_id: UUID;
        choice_type: ChoiceType;
        from_subaccount: ?Blob;
        amount: Nat;
    };

    public type PutPositionPreview = PutPositionArgs and {
        with_supply_apy_impact: Bool;
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

    public type SPosition<B> = {
        position_id: UUID;
        pool_id: UUID;
        timestamp: Nat;
        choice: B;
        amount: Nat;
        dissent: Float;
        consent: SRollingTimeline<Float>;
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

    public type SPool<A, B> = {
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

    public type UpdateAggregate<A, B> = ({aggregate: A; choice: B; amount: Nat; time: Nat;}) -> A;
    public type ComputeDissent<A, B> = ({aggregate: A; choice: B; amount: Nat; time: Nat;}) -> Float;
    public type ComputeConsent<A, B> = ({aggregate: A; choice: B; time: Nat;}) -> Float;

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

    public type PoolNotFoundError        = { #PoolNotFound: { pool_id: UUID; }; };
    public type InsuficientAmountError   = { #InsufficientAmount: { amount: Nat; minimum: Nat; }; };
    public type NewPoolError             = { #PoolAlreadyExists: { pool_id: UUID; }; } or TransferFromError;
    public type PositionAlreadyExistsError = { #PositionAlreadyExists: { position_id: UUID; }; };
    public type PutPositionError           = PoolNotFoundError or InsuficientAmountError or PositionAlreadyExistsError or TransferFromError;
    public type PutPositionResult          = Result<SPutPositionSuccess, Text>;
    public type NewPoolResult            = Result<PoolType, Text>;
    public type SNewPoolResult           = Result<SPoolType, Text>;

};