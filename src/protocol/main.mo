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

shared({ caller = admin }) actor class Protocol(args: MigrationTypes.Args) = this {

    // STABLE MEMBER
    stable var _state: MigrationTypes.State = Migrations.install(args);
    _state := Migrations.migrate(_state, args);

    // NON-STABLE MEMBER
    var _facade : ?SharedFacade.SharedFacade = null;

    // Unfortunately the principal of the canister cannot be used at the construction of the actor
    // because of the compiler error "cannot use self before self has been defined".
    // Therefore, one need to use an init method to initialize the facade.
    public shared({caller}) func init_facade() : async Result.Result<(), Text> {

        if (not Principal.equal(caller, admin)) {
            return #err("Only the admin can initialize the facade");
        };

        if (Option.isSome(_facade)) {
            return #err("The facade is already initialized");
        };

        let #v0_1_0(state) = _state;
        let { controller; queries; initialize; } = Factory.build({
            state;
            protocol = Principal.fromActor(this);
            admin;
        });
        switch(await* initialize()) {
            case (#err(e)) { return #err("Protocol.init_facade: " # e); };
            case (#ok) {};
        };
        
        _facade := ?SharedFacade.SharedFacade({ controller; queries; });
        #ok;
    };

    // Create a new vote
    public shared({caller}) func new_vote(args: Types.NewVoteArgs) : async Types.SNewVoteResult {
        await* getFacade().new_vote({ args with origin = caller; });
    };

    // Get the votes of the given origin
    public query func get_votes(args: Types.GetVotesArgs) : async [Types.SVoteType] {
        getFacade().get_votes(args);
    };

    public query func get_votes_by_author(args: Types.GetVotesByAuthorArgs) : async [Types.SVoteType] {
        getFacade().get_votes_by_author(args);
    };

    public query func find_vote(args: Types.FindVoteArgs) : async ?Types.SVoteType {
        getFacade().find_vote(args);
    };

    // ⚠️ THIS IS INTENTIONALLY A QUERY FUNCTION
    // DO NOT CHANGE IT TO A SHARED FUNCTION OTHERWISE THE PREVIEW WILL PUT AN ACTUAL BALLOT
    public query({caller}) func preview_ballot(args: Types.PutBallotArgs) : async Types.PutBallotResult {
        getFacade().put_ballot_for_free({ args with caller; });
    };

    // Add a ballot on the given vote identified by its vote_id
    public shared({caller}) func put_ballot(args: Types.PutBallotArgs) : async Types.PutBallotResult {
        await* getFacade().put_ballot({ args with caller; });
    };

    // Run the protocol
    public func run() : async Result.Result<(), Text> {
        await* getFacade().run();
    };

    // Get the ballots of the given account
    public query func get_ballots(args: Types.GetBallotArgs) : async [Types.SBallotType] {
        getFacade().get_ballots(args);
    };

    public query func get_user_supply({ account: Types.Account; }) : async Types.UserSupply {
        getFacade().get_user_supply({ account; });
    };

    // Get the ballots of the given vote
    public query func get_vote_ballots(vote_id: Types.UUID) : async [Types.SBallotType] {
        getFacade().get_vote_ballots(vote_id);
    };

    // Find a ballot by its vote_id and ballot_id
    public query func find_ballot(ballot_id: Types.UUID) : async ?Types.SBallotType {
        getFacade().find_ballot(ballot_id);
    };

    public shared func add_clock_offset(duration: Types.Duration) : async Result.Result<(), Text> {
        getFacade().add_clock_offset(duration);
    };

    public shared func set_clock_dilation_factor(dilation_factor: Float) : async Result.Result<(), Text> {
        getFacade().set_clock_dilation_factor(dilation_factor);
    };

    public shared({caller}) func set_timer_interval({ interval_s: Nat }) : async Result.Result<(), Text> {
        await* getFacade().set_timer_interval({ caller; interval_s; });
    };

    public shared({caller}) func start_timer() : async Result.Result<(), Text> {
        await* getFacade().start_timer({ caller; });
    };

    public shared({caller}) func stop_timer() : async Result.Result<(), Text> {
        getFacade().stop_timer({ caller; });
    };

    public query func get_info() : async Types.ProtocolInfo {
        getFacade().get_info();
    };

    public query func get_parameters() : async Types.SProtocolParameters {
        getFacade().get_parameters();
    };

    public query func get_lending_parameters() : async Types.LendingParameters {
        getFacade().get_lending_parameters();
    };

    public query func get_lending_index() : async Types.LendingIndex {
        getFacade().get_lending_index();
    };

    public query func get_loan_position(account: Types.Account) : async LendingTypes.LoanPosition {
        getFacade().get_loan_position(account);
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

    func getFacade() : SharedFacade.SharedFacade {
        switch(_facade){
            case (null) { Debug.trap("The facade is not initialized"); };
            case (?c) { c; };
        };
    };

};
