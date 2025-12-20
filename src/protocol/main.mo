import Factory        "Factory";
import Interface      "Interface";
import SharedFacade   "shared/SharedFacade";
import V0_2_0         "migrations/00-02-00-renamings/State";

import Principal      "mo:base/Principal";
import Debug          "mo:base/Debug";
import Option         "mo:base/Option";
import Result         "mo:base/Result";

(with migration = V0_2_0.migration)
shared({ caller = admin }) persistent actor class Protocol(args: V0_2_0.Args) : async Interface.ProtocolActor = this {

    var state: V0_2_0.State = V0_2_0.init(args);

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

        let { controller; queries; initialize; } = Factory.build({
            state;
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
    public shared({caller}) func new_pool(args: Interface.NewPoolArgs) : async Interface.SNewPoolResult {
        await* getFacade().new_pool({ args with origin = caller; });
    };

    // Get the pools of the given origin
    public query func get_pools(args: Interface.GetPoolsArgs) : async [Interface.SPoolType] {
        getFacade().get_pools(args);
    };

    public query func get_pools_by_author(args: Interface.GetPoolsByAuthorArgs) : async [Interface.SPoolType] {
        getFacade().get_pools_by_author(args);
    };

    public query func find_pool(args: Interface.FindPoolArgs) : async ?Interface.SPoolType {
        getFacade().find_pool(args);
    };

    // ⚠️ THIS IS INTENTIONALLY A QUERY FUNCTION
    // DO NOT CHANGE IT TO A SHARED FUNCTION OTHERWISE THE PREVIEW WILL PUT AN ACTUAL POSITION
    public query({caller}) func preview_position(args: Interface.PutPositionPreview) : async Interface.PutPositionResult {
        getFacade().put_position_for_free({ args with caller; });
    };

    // Add a position on the given pool identified by its pool_id
    public shared({caller}) func put_position(args: Interface.PutPositionArgs) : async Interface.PutPositionResult {
        await* getFacade().put_position({ args with caller; });
    };

    // Add a limit order on the given pool identified by its pool_id
    public shared({caller}) func put_limit_order(args: Interface.PutLimitOrderArgs) : async Interface.PutLimitOrderResult {
        await* getFacade().put_limit_order({ args with caller; });
    };

    public query func get_pool_limit_orders(pool_id: Interface.UUID) : async [(Interface.ChoiceType, [Interface.SLimitOrderType])] {
        getFacade().get_pool_limit_orders(pool_id);
    };

    public query func get_limit_orders(args: Interface.GetLimitOrderArgs) : async [Interface.SLimitOrderType] {
        getFacade().get_limit_orders(args);
    };

    public query func get_available_supply(account: Interface.Account) : async Float {
        getFacade().get_available_supply(account);
    };

    // Run the protocol
    // TODO: should be restricted to the admin
    public func run() : async () {
        await* getFacade().run();
    };

    public shared({caller}) func claim_mining_rewards(subaccount: ?Blob) : async ?Nat {
        await* getFacade().claim_mining_rewards({ owner = caller; subaccount; });
    };

    public query func get_mining_trackers() : async [(Interface.Account, Interface.MiningTracker)] {
        getFacade().get_mining_trackers();
    };

    public query({caller}) func get_mining_tracker(subaccount: ?Blob) : async ?Interface.MiningTracker {
        getFacade().get_mining_tracker({ owner = caller; subaccount; });
    };

    public query func get_mining_total_allocated() : async Interface.SRollingTimeline<Nat> {
        getFacade().get_mining_total_allocated();
    };

    public query func get_mining_total_claimed() : async Interface.SRollingTimeline<Nat> {
        getFacade().get_mining_total_claimed();
    };

    // Get the positions of the given account
    public query func get_positions(args: Interface.GetPositionArgs) : async [Interface.SPositionType] {
        getFacade().get_positions(args);
    };

    public query func get_user_supply({ account: Interface.Account; }) : async Interface.UserSupply {
        getFacade().get_user_supply({ account; });
    };

    // Get the positions of the given pool
    public query func get_pool_positions(pool_id: Interface.UUID) : async [Interface.SPositionType] {
        getFacade().get_pool_positions(pool_id);
    };

    // Find a position by its pool_id and position_id
    public query func find_position(position_id: Interface.UUID) : async ?Interface.SPositionType {
        getFacade().find_position(position_id);
    };

    public shared func add_clock_offset(duration: Interface.Duration) : async Result.Result<(), Text> {
        getFacade().add_clock_offset(duration);
    };

    public shared func set_clock_dilation_factor(dilation_factor: Float) : async Result.Result<(), Text> {
        getFacade().set_clock_dilation_factor(dilation_factor);
    };

    public query func get_info() : async Interface.ProtocolInfo {
        getFacade().get_info();
    };

    public query func get_parameters() : async Interface.SParameters {
        getFacade().get_parameters();
    };

    public query func get_collateral_token_price_usd() : async Float {
        getFacade().get_collateral_token_price_usd();
    };

    public query func get_supply_token_price_usd() : async Float {
        getFacade().get_supply_token_price_usd();
    };

    public query func get_lending_index() : async Interface.STimeline<Interface.LendingIndex> {
        getFacade().get_lending_index();
    };

    public query func get_loan_position(account: Interface.Account) : async Interface.LoanPosition {
        getFacade().get_loan_position(account);
    };

    public query func get_loans_info() : async { positions: [Interface.Loan]; max_ltv: Float } {
        getFacade().get_loans_info();
    };

    public shared func get_available_liquidities() : async Nat {
        await* getFacade().get_available_liquidities();
    };

    public query func get_unclaimed_fees() : async Nat {
        getFacade().get_unclaimed_fees();
    };

    public shared({caller}) func withdraw_fees({ to: Interface.Account; amount: Nat; }) : async Interface.TransferResult {
        await* getFacade().withdraw_fees({ caller; to; amount; });
    };

    public shared({caller}) func run_borrow_operation({ 
        subaccount: ?Blob;
        amount: Nat;
        kind: Interface.OperationKind;
    }) : async Result.Result<Interface.BorrowOperation, Text> {
        await* getFacade().run_borrow_operation({ caller; subaccount; amount; kind; });
    };

    // ⚠️ THIS IS INTENTIONALLY A QUERY FUNCTION
    // DO NOT CHANGE IT TO A SHARED FUNCTION OTHERWISE 
    // THE PREVIEW WILL ACTUALLY RUN THE BORROW OPERATION
    public query({caller}) func preview_borrow_operation({
        subaccount: ?Blob;
        amount: Nat;
        kind: Interface.OperationKind;
    }) : async Result.Result<Interface.BorrowOperation, Text> {
        getFacade().run_borrow_operation_for_free({ caller; subaccount; amount; kind; });
    };

    public shared({caller}) func run_supply_operation({
        subaccount: ?Blob;
        amount: Nat;
        kind: Interface.SupplyOperationKind;
    }) : async Result.Result<Interface.SupplyOperation, Text> {
        await* getFacade().run_supply_operation({ caller; subaccount; amount; kind; });
    };

    // ⚠️ THIS IS INTENTIONALLY A QUERY FUNCTION
    // DO NOT CHANGE IT TO A SHARED FUNCTION OTHERWISE
    // THE PREVIEW WILL ACTUALLY RUN THE SUPPLY OPERATION
    public query({caller}) func preview_supply_operation({
        subaccount: ?Blob;
        amount: Nat;
        kind: Interface.SupplyOperationKind;
    }) : async Result.Result<Interface.SupplyOperation, Text> {
        getFacade().run_supply_operation_for_free({ caller; subaccount; amount; kind; });
    };

    public query func get_supply_info(account: Interface.Account) : async Interface.SupplyInfo {
        getFacade().get_supply_info(account);
    };

    public query func get_all_supply_info() : async { positions: [Interface.SupplyInfo]; total_supplied: Float } {
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
