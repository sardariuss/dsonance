import Types          "Types";
import LendingTypes   "lending/Types";

import Result         "mo:base/Result";

module {

    type Result<Ok, Err>      = Result.Result<Ok, Err>;

    // --- From Types ---
    public type SNewPoolResult       = Types.SNewPoolResult;
    public type GetPoolsArgs         = Types.GetPoolsArgs;
    public type SPoolType            = Types.SPoolType;
    public type GetPoolsByAuthorArgs = Types.GetPoolsByAuthorArgs;
    public type FindPoolArgs         = Types.FindPoolArgs;
    public type PutPositionResult    = Types.PutPositionResult;
    public type GetPositionArgs      = Types.GetPositionArgs;
    public type SPositionType        = Types.SPositionType;
    public type Account              = Types.Account;
    public type UserSupply           = Types.UserSupply;
    public type UUID                 = Types.UUID;
    public type MiningTracker        = Types.MiningTracker;
    public type SRollingTimeline<T>  = Types.SRollingTimeline<T>;
    public type STimeline<T>         = Types.STimeline<T>;
    public type LendingIndex         = Types.LendingIndex;
    public type Duration             = Types.Duration;
    public type ProtocolInfo         = Types.ProtocolInfo;
    public type NewPoolArgs          = Types.NewPoolArgs;
    public type SParameters          = Types.SParameters;
    public type PutPositionPreview   = Types.PutPositionPreview;
    public type PutPositionArgs      = Types.PutPositionArgs;
    public type PutLimitOrderArgs    = Types.PutLimitOrderArgs;
    public type PreviewLimitOrderArgs = Types.PreviewLimitOrderArgs;
    public type PutLimitOrderResult  = Types.PutLimitOrderResult;
    public type ChoiceType           = Types.ChoiceType;
    public type LimitOrderType       = Types.LimitOrderType;
    public type GetLimitOrderArgs    = Types.GetLimitOrderArgs;
    public type LimitOrderWithResistanceType = Types.LimitOrderWithResistanceType;

    // --- From LendingTypes ---
    public type LoanPosition        = LendingTypes.LoanPosition;
    public type Loan                = LendingTypes.Loan;
    public type BorrowOperation     = LendingTypes.BorrowOperation;
    public type SupplyOperation     = LendingTypes.SupplyOperation;
    public type SupplyInfo          = LendingTypes.SupplyInfo;
    public type TransferResult      = LendingTypes.TransferResult;
    public type OperationKind       = LendingTypes.OperationKind;
    public type SupplyOperationKind = LendingTypes.SupplyOperationKind;

    public type ProtocolActor = actor {

        // --- Admin / Init ---
        init_facade : shared () -> async Result.Result<(), Text>;

        // --- Pools ---
        new_pool : shared (args : NewPoolArgs) -> async SNewPoolResult;
        get_pools : query GetPoolsArgs -> async [SPoolType];
        get_pools_by_author : query GetPoolsByAuthorArgs -> async [SPoolType];
        find_pool : query FindPoolArgs -> async ?SPoolType;

        // --- Positions ---
        preview_position :
            query (args : PutPositionPreview) ->
            async PutPositionResult;

        put_position :
            shared (args : PutPositionArgs) ->
            async PutPositionResult;

        get_positions :
            query GetPositionArgs ->
            async [SPositionType];

        get_user_supply :
            query ({ account : Account }) ->
            async UserSupply;

        get_pool_positions :
            query UUID ->
            async [SPositionType];

        find_position :
            query UUID ->
            async ?SPositionType;

        // --- Limit Orders ---
        preview_limit_order :
            query (args : PreviewLimitOrderArgs) ->
            async PutLimitOrderResult;

        put_limit_order :
            shared (args : PutLimitOrderArgs) ->
            async PutLimitOrderResult;
        
        get_pool_limit_orders :
            query (UUID, Nat) ->
            async [(ChoiceType, [LimitOrderWithResistanceType])];

        get_limit_orders :
            query GetLimitOrderArgs ->
            async [LimitOrderType];

        get_available_supply :
            query Account ->
            async Float;

        // --- Mining ---
        claim_mining_rewards :
            shared (subaccount : ?Blob) ->
            async ?Nat;

        get_mining_trackers :
            query () ->
            async [(Account, MiningTracker)];

        get_mining_tracker :
            query (subaccount : ?Blob) ->
            async ?MiningTracker;

        get_mining_total_allocated :
            query () ->
            async SRollingTimeline<Nat>;

        get_mining_total_claimed :
            query () ->
            async SRollingTimeline<Nat>;

        // --- Lending / Borrow ---
        get_loan_position :
            query Account ->
            async LoanPosition;

        get_loans_info :
            query () ->
            async { positions : [Loan]; max_ltv : Float };

        run_borrow_operation :
            shared { subaccount : ?Blob; amount : Nat; kind : OperationKind } ->
            async Result.Result<BorrowOperation, Text>;

        preview_borrow_operation :
            query { subaccount : ?Blob; amount : Nat; kind : OperationKind } ->
            async Result.Result<BorrowOperation, Text>;

        // --- Lending / Supply ---
        run_supply_operation :
            shared { subaccount : ?Blob; amount : Nat; kind : SupplyOperationKind } ->
            async Result.Result<SupplyOperation, Text>;

        preview_supply_operation :
            query { subaccount : ?Blob; amount : Nat; kind : SupplyOperationKind } ->
            async Result.Result<SupplyOperation, Text>;

        get_supply_info :
            query Account ->
            async SupplyInfo;

        get_all_supply_info :
            query () ->
            async { positions : [SupplyInfo]; total_supplied : Float };

        // --- Liquidity ---
        get_available_liquidities : shared () -> async Nat;
        get_unclaimed_fees : query () -> async Nat;

        withdraw_fees :
            shared { to : Account; amount : Nat } ->
            async TransferResult;

        // --- Prices & Index ---
        get_collateral_token_price_usd : query () -> async Float;
        get_supply_token_price_usd : query () -> async Float;
        get_lending_index : query () -> async STimeline<LendingIndex>;

        // --- Operations ---
        run : shared () -> async ();
        add_clock_offset : shared Duration -> async Result.Result<(), Text>;
        set_clock_dilation_factor : shared Float -> async Result.Result<(), Text>;
        get_info : query () -> async ProtocolInfo;
        get_parameters : query () -> async SParameters;

        // --- ICRC Standards ---
        icrc10_supported_standards :
            query () ->
            async [{ url : Text; name : Text }];

        icrc28_trusted_origins :
            shared () ->
            async { trusted_origins : [Text] };
    };

};