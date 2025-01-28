import ProtocolTypes "../protocol/Types";

import Map           "mo:map/Map";
import Array         "mo:base/Array";
import Principal     "mo:base/Principal";
import Result        "mo:base/Result";
import Option        "mo:base/Option";
import Iter          "mo:base/Iter";
import Debug         "mo:base/Debug";

import Protocol      "canister:protocol";


shared({ caller = admin }) actor class Backend() = this {

    type YesNoAggregate = ProtocolTypes.YesNoAggregate;
    type YesNoChoice = ProtocolTypes.YesNoChoice;
    type SVoteType = ProtocolTypes.SVoteType;
    type VoteInfo = {
        text: Text;
        visible: Bool;
    };
    type SYesNoVote = ProtocolTypes.SVote<YesNoAggregate, YesNoChoice> and { info: VoteInfo };
    type Account = ProtocolTypes.Account;
    type UUID = ProtocolTypes.UUID;

    type SNewVoteResult = Result.Result<SYesNoVote, SNewVoteError>;
    type SNewVoteError = ProtocolTypes.NewVoteError or { #AnonymousCaller; #CategoryNotFound; };

    stable let _infos = Map.new<UUID, VoteInfo>();

    public shared({ caller }) func new_vote({
        text: Text;
        vote_id: UUID;
        category: Text;
        from_subaccount: ?Blob;
    }) : async SNewVoteResult {
        if (Principal.isAnonymous(caller)){
            return #err(#AnonymousCaller);
        };
        if (not Map.has(_categories, Map.thash, category)){
            return #err(#CategoryNotFound);
        };
        let new_result = await Protocol.new_vote({ type_enum = #YES_NO; vote_id; account = { owner = caller; subaccount = from_subaccount; } });
        Result.mapOk(new_result, func(vote_type: SVoteType) : SYesNoVote {
            switch(vote_type) {
                case(#YES_NO(vote)) {
                    let info = { text; visible = true; };
                    Map.set(_infos, Map.thash, vote.vote_id, info);
                    switch(Map.get(_categories, Map.thash, category)) {
                        case(null){ /* Shall not happen */ };
                        case(?ids) { Map.set(_categories, Map.thash, category, Array.append(ids, [vote.vote_id])); };
                    };
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

    public composite query func get_votes({ category: ?Text }) : async [SYesNoVote] {
        let filter_ids = Option.map(category, func(cat: Text) : [UUID] {
            switch(Map.get(_categories, Map.thash, cat)){
                case(null) { Debug.trap("Category not found"); };
                case(?ids) { ids; };
            };
        });
        let votes = await Protocol.get_votes({ origin = Principal.fromActor(this); filter_ids; });
        Array.map(votes, func(vote_type: SVoteType) : SYesNoVote {
            with_info(vote_type);
        });
    };
  
    stable let _categories = Map.new<Text, [UUID]>();

    public shared func add_categories(categories: [Text]) : async () {
        for (category in Array.vals(categories)) {
            Map.set(_categories, Map.thash, category, []);
        };
    };

    public shared func remove_category(category: Text) : async () {
        Map.delete(_categories, Map.thash, category);
    };

    public query func get_categories() : async [Text] {
        Iter.toArray(Map.keys(_categories));
    };

    public query func get_vote_by_category() : async [(Text, [UUID])] {
        Iter.toArray(Map.entries(_categories));
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

};