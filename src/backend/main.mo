import ProtocolTypes "../protocol/Types";

import Map           "mo:map/Map";
import Array         "mo:base/Array";
import Principal     "mo:base/Principal";
import Result        "mo:base/Result";
import Option        "mo:base/Option";
import Debug         "mo:base/Debug";
import Time          "mo:base/Time";

import Protocol      "canister:protocol";

shared({ caller = admin }) persistent actor class Backend() = this {

    type YesNoAggregate = ProtocolTypes.YesNoAggregate;
    type YesNoChoice = ProtocolTypes.YesNoChoice;
    type SVoteType = ProtocolTypes.SVoteType;
    type SBallotType = ProtocolTypes.SBallotType;
    type QueryDirection = ProtocolTypes.QueryDirection;
    type VoteInfo = {
        text: Text;
        visible: Bool;
        thumbnail: Blob;
    };
    type User = {
        principal: Principal;
        nickname: Text;
        joinedDate: Int;
    };
    type SYesNoVote = ProtocolTypes.SVote<YesNoAggregate, YesNoChoice> and { info: VoteInfo };
    type SYesNoBallot = ProtocolTypes.SBallot<YesNoChoice>;
    type SYesNoBallotWithUser = ProtocolTypes.SBallot<YesNoChoice> and { user: ?User };
    type Account = ProtocolTypes.Account;
    type UUID = ProtocolTypes.UUID;
    type GetVotesByAuthorArgs = ProtocolTypes.GetVotesByAuthorArgs;
    type SNewVoteResult = Result.Result<SYesNoVote, Text>;

    let _infos = Map.new<UUID, VoteInfo>();
    let _users = Map.new<Principal, User>();

    public shared({ caller }) func new_vote({
        text: Text;
        thumbnail: Blob;
        id: UUID;
        from_subaccount: ?Blob;
    }) : async SNewVoteResult {
        if (Principal.isAnonymous(caller)){
            return #err("Anonymous users cannot create a vote");
        };
        let new_result = await Protocol.new_vote({ type_enum = #YES_NO; id; account = { owner = caller; subaccount = from_subaccount; } });
        Result.mapOk(new_result, func(vote_type: SVoteType) : SYesNoVote {
            switch(vote_type) {
                case(#YES_NO(vote)) {
                    let info = { text; thumbnail; visible = true; };
                    Map.set(_infos, Map.thash, vote.vote_id, info);
                    { vote with info; };
                };
            };
        });
    };

    public composite query func get_vote({ vote_id: UUID }) : async ?SYesNoVote {
        let vote = await Protocol.find_vote({ vote_id; });
        Option.map(vote, func(vote_type: SVoteType) : SYesNoVote {
            with_info(vote_type);
        });
    };

    public composite query func get_votes({ previous: ?UUID; limit: Nat; direction: QueryDirection; }) : async [SYesNoVote] {

        // Fetch votes using the collected `filter_ids`
        let votes = await Protocol.get_votes({ origin = Principal.fromActor(this); previous; limit; direction; });

        // Process and return votes
        Array.map(votes, func(vote_type: SVoteType) : SYesNoVote {
            with_info(vote_type);
        });
    };

    public composite query func get_votes_by_author(args: GetVotesByAuthorArgs) : async [SYesNoVote] {
        let votes = await Protocol.get_votes_by_author(args);
        Array.map(votes, func(vote_type: SVoteType) : SYesNoVote {
            with_info(vote_type);
        });
    };

    public shared({caller}) func set_vote_visible({vote_id: UUID; visible: Bool; }) : async Result.Result<(), Text> {

        if (caller != admin) {
            return #err("Only the admin can set or unset the visibility of a vote");
        };

        let info = switch(Map.get<UUID, VoteInfo>(_infos, Map.thash, vote_id)){
            case(null) { return #err("Vote not found"); };
            case(?i) { i; };
        };

        Map.set(_infos, Map.thash, vote_id, { info with visible; });
        #ok;
    };

    public shared func create_user({ principal: Principal; nickname: Text; }) : async Result.Result<User, Text> {
        if (Principal.isAnonymous(principal)) {
            return #err("Anonymous users cannot be created");
        };

        if (Map.has<Principal, User>(_users, Map.phash, principal)) {
            return #err("User already exists");
        };
        
        let user = { principal; nickname; joinedDate = Time.now(); };
        Map.set(_users, Map.phash, principal, user);
        #ok(user);
    };

    public query func get_user({ principal: Principal }) : async ?User {
        Map.get<Principal, User>(_users, Map.phash, principal);
    };

    public shared({ caller }) func set_user_nickname({ nickname: Text }) : async Result.Result<(), Text> {
        if (Principal.isAnonymous(caller)) {
            return #err("Anonymous users cannot set a nickname");
        };

        let user = switch(Map.get<Principal, User>(_users, Map.phash, caller)){
            case(null) { return #err("User not found"); };
            case(?u) { { u with nickname; }; };
        };

        Map.set(_users, Map.phash, caller, user);
        #ok;
    };

    public composite query func get_vote_ballots(vote_id: Text) : async [SYesNoBallotWithUser] {
        let ballots = await Protocol.get_vote_ballots(vote_id);
        Array.map(ballots, func(ballot: ProtocolTypes.SBallotType) : SYesNoBallotWithUser {
            switch(ballot) {
                case(#YES_NO(b)) {
                    { b with user = Map.get<Principal, User>(_users, Map.phash, b.from.owner); };
                };
            };
        });
    };

    func with_info(vote_type: SVoteType) : SYesNoVote {
        switch(vote_type){
            case(#YES_NO(vote)) {
                switch(Map.get<UUID, VoteInfo>(_infos, Map.thash, vote.vote_id)){
                    case(null) { Debug.trap("Vote info not found"); };
                    case(?info) { { vote with info; }; };
                };
            };
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