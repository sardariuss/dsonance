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
        reward: Nat;
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
        #err: Icrc1TransferError or { #Trapped : { error_code: Error.ErrorCode; }};
    };

    public type Duration = {
        #YEARS: Nat;
        #DAYS: Nat;
        #HOURS: Nat;
        #MINUTES: Nat;
        #SECONDS: Nat;
        #NS: Nat;
    };

    public type MintingInfo = {
        amount_minted: Timeline<Nat>;
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
        id: UUID;
    };

    public type LockRegister = {
        var time_last_dispense: Nat;
        total_amount: Timeline<Nat>;
        locks: BTree<Lock, Ballot<YesNoChoice>>; // TODO: use the BallotType or even a generic lock type instead
        yield: {
            rate: Float;
            var cumulated: Float;
            contributions: {
                var sum_current: Float;
                var sum_cumulated: Float;
            };
        };
    };

    public type ProtocolParameters = {
        contribution_per_ns: Float;
        nominal_lock_duration: Duration;
        minimum_ballot_amount: Nat;
        dissent_steepness: Float;
        consent_steepness: Float;
        age_coefficient: Float;
        max_age: Nat;
        author_fee: Nat;
        author_share: Float;
        timer: TimerParameters;
        decay: {
            half_life: Duration;
            time_init: Nat;
        };
        clock: ClockParameters;
    };

    public type Args = {
        #init: InitArgs;
        #upgrade: UpgradeArgs;
        #downgrade: DowngradeArgs;
        #none;
    };

    public type InitArgs = {
        btc: {
            ledger: Principal;
            fee: Nat;
        };
        dsn: {
            ledger: Principal;
            fee: Nat;
        };
        parameters: {
            contribution_per_day: Nat;
            age_coefficient: Float;
            max_age: Duration;
            ballot_half_life: Duration;
            nominal_lock_duration: Duration;
            minimum_ballot_amount: Nat;
            dissent_steepness: Float;
            consent_steepness: Float;
            author_fee: Nat;
            author_share: Float;
            timer_interval_s: Nat;
            clock: ClockInitArgs;
        };
    };
    public type UpgradeArgs = {
    };
    public type DowngradeArgs = {
    };

    public type State = {
        vote_register: VoteRegister;
        ballot_register: BallotRegister;
        lock_register: LockRegister;
        btc: {
            ledger: ICRC1 and ICRC2;
            fee: Nat;
            debt_register: DebtRegister;
        };
        dsn: {
            ledger: ICRC1 and ICRC2;
            fee: Nat;
            debt_register: DebtRegister;
        };
        parameters: ProtocolParameters;
        minting_info: MintingInfo;
    };
  
};