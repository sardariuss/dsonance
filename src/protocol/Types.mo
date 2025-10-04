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
    public type VoteRegister             = Types.Current.VoteRegister;
    public type VoteType                 = Types.Current.VoteType;
    public type YesNoAggregate           = Types.Current.YesNoAggregate;
    public type Decayed                  = Types.Current.Decayed;
    public type YesNoChoice              = Types.Current.YesNoChoice;
    public type Timeline<T>              = Types.Current.Timeline<T>;
    public type TimedData<T>             = Types.Current.TimedData<T>;
    public type Vote<A, B>               = Types.Current.Vote<A, B>;
    public type LockInfo                 = Types.Current.LockInfo;
    public type Ballot<B>                = Types.Current.Ballot<B>;
    public type Duration                 = Types.Current.Duration;
    public type State                    = Types.Current.State;
    public type ClockParameters          = Types.Current.ClockParameters;
    public type UUID                     = Types.Current.UUID;
    public type Lock                     = Types.Current.Lock;
    public type DebtInfo                 = Types.Current.DebtInfo;
    public type Transfer                 = Types.Current.Transfer;
    public type TransferResult           = Types.Current.TransferResult;
    public type BallotType               = Types.Current.BallotType;
    public type BallotRegister           = Types.Current.BallotRegister;
    public type Parameters               = Types.Current.Parameters;
    public type LendingParameters        = Types.Current.LendingParameters;
    public type DurationScalerParameters = Types.Current.DurationScalerParameters;
    public type Foresight                = Types.Current.Foresight;
    public type Register<T>              = Types.Current.Register<T>;
    public type DebtRegister             = Types.Current.DebtRegister;
    public type DebtRecord               = Types.Current.DebtRecord;
    public type MinterParameters         = Types.Current.MinterParameters;
    public type ParticipationParameters  = Types.Current.ParticipationParameters;
    public type ParticipationTracker     = Types.Current.ParticipationTracker;
    public type LockSchedulerState       = Types.Current.LockSchedulerState;
    public type YieldState               = Types.Current.YieldState;
    public type TransferError            = Types.Current.TransferError;
    public type Index                    = Types.Current.Index;
    public type Utilization              = Types.Current.Utilization;
    public type LendingIndex             = Types.Current.LendingIndex;
    public type ForesightParameters      = Types.Current.ForesightParameters;

    // CANISTER ARGS

    public type NewVoteArgs = {
        account: Account;
        type_enum: VoteTypeEnum;
        id: UUID;
    };

    public type GetVotesArgs = {
        origin: Principal;
        previous: ?UUID;
        limit: Nat;
    };

    public type GetVotesByAuthorArgs = {
        author: Account;
        previous: ?UUID;
        limit: Nat;
    };

    public type GetBallotArgs = {
        account: Account;
        previous: ?UUID;
        limit: Nat;
        filter_active: Bool;
    };

    public type FindVoteArgs = {
        vote_id: UUID;
    };

    public type PutBallotArgs = {
        id: UUID;
        vote_id: UUID;
        choice_type: ChoiceType;
        from_subaccount: ?Blob;
        amount: Nat;
    };

    public type PutBallotPreview = PutBallotArgs and {
        with_supply_apy_impact: Bool;
    };

    public type FindBallotArgs = {
        vote_id: UUID;
        ballot_id: UUID;
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

    public type SVoteType = {
        #YES_NO: SVote<YesNoAggregate, YesNoChoice>;
    };

    public type SBallotType = {
        #YES_NO: SBallot<YesNoChoice>;
    };

    public type SDebtInfo = {
        id: UUID;
        account: Account;
        amount: STimeline<DebtRecord>;
        transferred: Nat;
        transfers: [Transfer];
    };

    public type STimeline<T> = {
        current: TimedData<T>;
        history: [TimedData<T>];
    };

    public type SBallot<B> = {
        ballot_id: UUID;
        vote_id: UUID;
        timestamp: Nat;
        choice: B;
        amount: Nat;
        dissent: Float;
        consent: STimeline<Float>;
        tx_id: Nat;
        from: Account;
        decay: Float;
        foresight: Foresight;
        hotness: Float;
        lock: ?SLockInfo;
    };

    public type SLockInfo = {
        duration_ns: STimeline<Nat>;
        release_date: Nat;
    };

    public type SVote<A, B> = {
        vote_id: UUID;
        date: Nat;
        origin: Principal;
        aggregate: STimeline<A>;
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
        amount_minted: STimeline<Float>;
    };

    public type SParameters = {
        foresight: {
            dissent_steepness: Float;
            consent_steepness: Float;
            max_age: Duration;
            age_coefficient: Float;
        };
        duration_scaler: DurationScalerParameters;
        minimum_ballot_amount: Nat;
        ballot_half_life: Duration;
        clock: SClockParameters;
        lending: LendingParameters;
        participation: {
            emission_half_life_s: Float;
            emission_total_amount: Nat;
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

    public type BallotAggregatorOutcome<A> = {
        aggregate: {
            update: A;
        };
        ballot: {
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

    public type VoteTypeEnum = {
        #YES_NO;
    };

    public type YesNoBallot = Ballot<YesNoChoice>;
    public type YesNoVote = Vote<YesNoAggregate, YesNoChoice>;

    // RESULT/ERROR TYPES

    public type PutBallotSuccess = {
        new: BallotType;
        previous: [BallotType];
    };

    public type SPutBallotSuccess = {
        new: SBallotType;
        previous: [SBallotType];
    };

    public type VoteNotFoundError        = { #VoteNotFound: { vote_id: UUID; }; };
    public type InsuficientAmountError   = { #InsufficientAmount: { amount: Nat; minimum: Nat; }; };
    public type NewVoteError             = { #VoteAlreadyExists: { vote_id: UUID; }; } or TransferFromError;
    public type BallotAlreadyExistsError = { #BallotAlreadyExists: { ballot_id: UUID; }; };
    public type PutBallotError           = VoteNotFoundError or InsuficientAmountError or BallotAlreadyExistsError or TransferFromError;
    public type PutBallotResult          = Result<SPutBallotSuccess, Text>;
    public type NewVoteResult            = Result<VoteType, Text>;
    public type SNewVoteResult           = Result<SVoteType, Text>;

};