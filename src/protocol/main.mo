import Types          "Types";
import SharedFacade   "shared/SharedFacade";
import Factory        "Factory";
import MigrationTypes "migrations/Types";
import Migrations     "migrations/Migrations";

import Time           "mo:base/Time";
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
    public shared({caller}) func init_facade() : async () {

        if (not Principal.equal(caller, admin)) {
            Debug.trap("Only the admin can initialize the facade");
        };

        if (Option.isSome(_facade)) {
            Debug.trap("The facade is already initialized");
        };

        switch(_state){
            case(#v0_1_0(stable_data)) {
                _facade := ?SharedFacade.SharedFacade(Factory.build({stable_data with 
                    provider = Principal.fromActor(this);
                    admin;
                }));
            };
        };
    };

    // Create a new vote
    public shared({caller}) func new_vote(args: Types.NewVoteArgs) : async Types.SNewVoteResult {
        await* getFacade().new_vote({ args with origin = caller; });
    };

    // Get the votes of the given origin
    public query func get_votes(args: Types.GetVotesArgs) : async [Types.SVoteType] {
        getFacade().get_votes(args);
    };

    public query func find_vote(args: Types.FindVoteArgs) : async ?Types.SVoteType {
        getFacade().find_vote(args);
    };

    public query({caller}) func preview_ballot(args: Types.PutBallotArgs) : async Types.SPreviewBallotResult {
        getFacade().preview_ballot({ args with caller; });
    };

    // Add a ballot on the given vote identified by its vote_id
    public shared({caller}) func put_ballot(args: Types.PutBallotArgs) : async Types.PutBallotResult {
        await* getFacade().put_ballot({ args with caller; });
    };

    // Run the protocol
    public func run() : async () {
        await* getFacade().run();
    };

    public query func get_amount_minted() : async Types.STimeline<Nat> {
        getFacade().get_amount_minted();
    };

    public query func get_total_locked() : async Types.STimeline<Nat> {
        getFacade().get_total_locked();
    };

    public query func get_protocol_parameters() : async Types.ProtocolParameters {
        getFacade().get_protocol_parameters();
    };

    // Get the ballots of the given account
    public query func get_ballots(account: Types.Account) : async [Types.SBallotType] {
        getFacade().get_ballots(account);
    };

    // Get the ballots of the given vote
    public query func get_vote_ballots(vote_id: Types.UUID) : async [Types.SBallotType] {
        getFacade().get_vote_ballots(vote_id);
    };

    // Find a ballot by its vote_id and ballot_id
    public query func find_ballot(ballot_id: Types.UUID) : async ?Types.SBallotType {
        getFacade().find_ballot(ballot_id);
    };

    public query func current_decay() : async Float {
        getFacade().current_decay();
    };

    public query func decay_params() : async Types.DecayParameters {
        getFacade().decay_params();
    };

    public query func get_parameters() : async Types.SClockParameters {
        getFacade().get_parameters();
    };

    public query func clock_info() : async Types.ClockInfo {
        getFacade().clock_info();
    };

    public shared func add_offset(duration: Types.Duration) : async Result.Result<(), Text> {
        getFacade().add_offset(duration);
    };

    public shared func set_dilation_factor(dilation_factor: Float) : async Result.Result<(), Text> {
        getFacade().set_dilation_factor(dilation_factor);
    };

    public query func get_time() : async Time.Time {
        getFacade().get_time();
    };

    public query func get_timer() : async ?Types.TimerParameters {
        getFacade().get_timer();
    };

    public shared({caller}) func set_timer({ duration_s: Nat }) : async Result.Result<(), Text> {
        await* getFacade().set_timer({ caller; duration_s; });
    };

    public shared({caller}) func stop_timer() : async Result.Result<(), Text> {
        getFacade().stop_timer({ caller; });
    };

    func getFacade() : SharedFacade.SharedFacade {
        switch(_facade){
            case (null) { Debug.trap("The facade is not initialized"); };
            case (?c) { c; };
        };
    };

};
