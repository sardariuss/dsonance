import Types          "Types";
import LendingTypes   "lending/Types";
import SharedFacade   "shared/SharedFacade";
import Factory        "Factory";
import MigrationTypes "migrations/Types";
import Migrations     "migrations/Migrations";

import Principal      "mo:base/Principal";
import Debug          "mo:base/Debug";
import Option         "mo:base/Option";
import Result         "mo:base/Result";

shared({ caller = admin }) persistent actor class Protocol(args: MigrationTypes.Args) = this {

    var state: MigrationTypes.State = Migrations.install(args);
    state := Migrations.migrate(state, args);

    transient var facade : ?SharedFacade.SharedFacade = null;

    // Unfortunately the principal of the canister cannot be used at the construction of the actor
    // because of the compiler error "cannot use self before self has been defined".
    // Therefore, one need to use an init method to initialize the facade.
    public shared({caller}) func init_facade() : async Result.Result<(), Text> {

        if (not Principal.equal(caller, admin)) {
            return #err("Only the admin can initialize the facade");
        };

        if (Option.isSome(facade)) {
            return #err("The facade is already initialized");
        };

        let statev2 = switch(state){
            case(#v0_2_0(s)) { s; };
            case(_){ Debug.trap("Unsupported state version, v0_2_0 expected"); };
        };
        let { controller; queries; initialize; } = Factory.build({
            state = statev2;
            protocol = Principal.fromActor(this);
            admin;
        });
        switch(await* initialize()) {
            case (#err(e)) { return #err("Protocol.init_facade: " # e); };
            case (#ok) {};
        };
        
        facade := ?SharedFacade.SharedFacade({ controller; queries; });
        #ok;
    };

    // Create a new pool
    public shared({caller}) func new_pool(args: Types.NewPoolArgs) : async Types.SNewPoolResult {
        await* getFacade().new_pool({ args with origin = caller; });
    };

    // Get the pools of the given origin
    public query func get_pools(args: Types.GetPoolsArgs) : async [Types.SPoolType] {
        getFacade().get_pools(args);
    };

    public query func get_pools_by_author(args: Types.GetPoolsByAuthorArgs) : async [Types.SPoolType] {
        getFacade().get_pools_by_author(args);
    };

    public query func find_pool(args: Types.FindPoolArgs) : async ?Types.SPoolType {
        getFacade().find_pool(args);
    };

    // ⚠️ THIS IS INTENTIONALLY A QUERY FUNCTION
    // DO NOT CHANGE IT TO A SHARED FUNCTION OTHERWISE THE PREVIEW WILL PUT AN ACTUAL POSITION
    public query({caller}) func preview_position(args: Types.PutPositionPreview) : async Types.PutPositionResult {
        getFacade().put_position_for_free({ args with caller; });
    };

    // Add a position on the given pool identified by its pool_id
    public shared({caller}) func put_position(args: Types.PutPositionArgs) : async Types.PutPositionResult {
        await* getFacade().put_position({ args with caller; });
    };

    // Run the protocol
    // TODO: should be restricted to the admin
    public func run() : async () {
        await* getFacade().run();
    };

    public shared({caller}) func claim_mining_rewards(subaccount: ?Blob) : async ?Nat {
        await* getFacade().claim_mining_rewards({ owner = caller; subaccount; });
    };

    public query func get_mining_trackers() : async [(Types.Account, Types.MiningTracker)] {
        getFacade().get_mining_trackers();
    };

    public query({caller}) func get_mining_tracker(subaccount: ?Blob) : async ?Types.MiningTracker {
        getFacade().get_mining_tracker({ owner = caller; subaccount; });
    };

    public query func get_mining_total_allocated() : async Types.SRollingTimeline<Nat> {
        getFacade().get_mining_total_allocated();
    };

    public query func get_mining_total_claimed() : async Types.SRollingTimeline<Nat> {
        getFacade().get_mining_total_claimed();
    };

    // Get the positions of the given account
    public query func get_positions(args: Types.GetPositionArgs) : async [Types.SPositionType] {
        getFacade().get_positions(args);
    };

    public query func get_user_supply({ account: Types.Account; }) : async Types.UserSupply {
        getFacade().get_user_supply({ account; });
    };

    // Get the positions of the given pool
    public query func get_pool_positions(pool_id: Types.UUID) : async [Types.SPositionType] {
        getFacade().get_pool_positions(pool_id);
    };

    // Find a position by its pool_id and position_id
    public query func find_position(position_id: Types.UUID) : async ?Types.SPositionType {
        getFacade().find_position(position_id);
    };

    public shared func add_clock_offset(duration: Types.Duration) : async Result.Result<(), Text> {
        getFacade().add_clock_offset(duration);
    };

    public shared func set_clock_dilation_factor(dilation_factor: Float) : async Result.Result<(), Text> {
        getFacade().set_clock_dilation_factor(dilation_factor);
    };

    public query func get_info() : async Types.ProtocolInfo {
        getFacade().get_info();
    };

    public query func get_parameters() : async Types.SParameters {
        getFacade().get_parameters();
    };

    public query func get_collateral_token_price_usd() : async Float {
        getFacade().get_collateral_token_price_usd();
    };

    public query func get_supply_token_price_usd() : async Float {
        getFacade().get_supply_token_price_usd();
    };

    public query func get_lending_index() : async Types.STimeline<Types.LendingIndex> {
        getFacade().get_lending_index();
    };

    public query func get_loan_position(account: Types.Account) : async LendingTypes.LoanPosition {
        getFacade().get_loan_position(account);
    };

    public query func get_loans_info() : async { positions: [LendingTypes.Loan]; max_ltv: Float } {
        getFacade().get_loans_info();
    };

    public shared func get_available_liquidities() : async Nat {
        await* getFacade().get_available_liquidities();
    };

    public query func get_unclaimed_fees() : async Nat {
        getFacade().get_unclaimed_fees();
    };

    public shared({caller}) func withdraw_fees({ to: Types.Account; amount: Nat; }) : async LendingTypes.TransferResult {
        await* getFacade().withdraw_fees({ caller; to; amount; });
    };

    public shared({caller}) func run_borrow_operation({ 
        subaccount: ?Blob;
        amount: Nat;
        kind: LendingTypes.OperationKind;
    }) : async Result.Result<LendingTypes.BorrowOperation, Text> {
        await* getFacade().run_borrow_operation({ caller; subaccount; amount; kind; });
    };

    // ⚠️ THIS IS INTENTIONALLY A QUERY FUNCTION
    // DO NOT CHANGE IT TO A SHARED FUNCTION OTHERWISE 
    // THE PREVIEW WILL ACTUALLY RUN THE BORROW OPERATION
    public query({caller}) func preview_borrow_operation({
        subaccount: ?Blob;
        amount: Nat;
        kind: LendingTypes.OperationKind;
    }) : async Result.Result<LendingTypes.BorrowOperation, Text> {
        getFacade().run_borrow_operation_for_free({ caller; subaccount; amount; kind; });
    };

    public shared({caller}) func run_supply_operation({
        subaccount: ?Blob;
        amount: Nat;
        kind: LendingTypes.SupplyOperationKind;
    }) : async Result.Result<LendingTypes.SupplyOperation, Text> {
        await* getFacade().run_supply_operation({ caller; subaccount; amount; kind; });
    };

    // ⚠️ THIS IS INTENTIONALLY A QUERY FUNCTION
    // DO NOT CHANGE IT TO A SHARED FUNCTION OTHERWISE
    // THE PREVIEW WILL ACTUALLY RUN THE SUPPLY OPERATION
    public query({caller}) func preview_supply_operation({
        subaccount: ?Blob;
        amount: Nat;
        kind: LendingTypes.SupplyOperationKind;
    }) : async Result.Result<LendingTypes.SupplyOperation, Text> {
        getFacade().run_supply_operation_for_free({ caller; subaccount; amount; kind; });
    };

    public query func get_supply_info(account: Types.Account) : async LendingTypes.SupplyInfo {
        getFacade().get_supply_info(account);
    };

    public query func get_all_supply_info() : async { positions: [LendingTypes.SupplyInfo]; total_supplied: Float } {
        getFacade().get_all_supply_info();
    };

    func getFacade() : SharedFacade.SharedFacade {
        switch(facade){
            case (null) { Debug.trap("The facade is not initialized"); };
            case (?c) { c; };
        };
    };

    type SupportedStandard = {
        url: Text;
        name: Text;
    };

    public query func icrc10_supported_standards() : async [SupportedStandard] {
        return [
            {
                url = "https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-10/ICRC-10.md";
                name = "ICRC-10";
            },
            {
                url = "https://github.com/dfinity/wg-identity-authentication/blob/main/topics/icrc_28_trusted_origins.md";
                name = "ICRC-28";
            }
        ];
    };

    type Icrc28TrustedOriginsResponse = {
        trusted_origins: [Text];
    };

    public func icrc28_trusted_origins() : async Icrc28TrustedOriginsResponse {
        let trusted_origins = [
            "https://hrr6s-tyaaa-aaaap-anxha-cai.icp0.io",
            "https://hrr6s-tyaaa-aaaap-anxha-cai.raw.icp0.io",
            "https://hrr6s-tyaaa-aaaap-anxha-cai.ic0.app",
            "https://hrr6s-tyaaa-aaaap-anxha-cai.raw.ic0.app",
            "https://hrr6s-tyaaa-aaaap-anxha-cai.icp0.icp-api.io",
            "https://hrr6s-tyaaa-aaaap-anxha-cai.icp-api.io",
            "https://app.dsonance.xyz",
        ];
        return { trusted_origins; };
    };

};
