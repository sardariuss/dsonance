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
    type SYesNoVote = ProtocolTypes.SVote<YesNoAggregate, YesNoChoice> and {
        text: ?Text;
    };
    type Account = ProtocolTypes.Account;
    type UUID = ProtocolTypes.UUID;

    type SNewVoteResult = Result.Result<SYesNoVote, SNewVoteError>;
    type SNewVoteError = ProtocolTypes.NewVoteError or { #AnonymousCaller; #CategoryNotFound; };

    stable let _texts = Map.new<UUID, Text>();

    public shared({ caller }) func new_vote({text: Text; vote_id: UUID; category: Text;}) : async SNewVoteResult {
        if (Principal.isAnonymous(caller)){
            return #err(#AnonymousCaller);
        };
        let category_ids = switch(Map.get(_categories, Map.thash, category)) {
            case(null){ return #err(#CategoryNotFound); };
            case(?ids) { ids; };
        };
        Result.mapOk(await Protocol.new_vote({ type_enum = #YES_NO; vote_id; }), func(vote_type: SVoteType) : SYesNoVote {
            switch(vote_type) {
                case(#YES_NO(vote)) {
                    Map.set(_texts, Map.thash, vote.vote_id, text);
                    Map.set(_categories, Map.thash, category, Array.append(category_ids, [vote.vote_id]));
                    { vote with text = ?text; };
                };
            };
        });
    };

    public query func get_vote_text({ vote_id: UUID }) : async ?Text {
        Map.get<UUID, Text>(_texts, Map.thash, vote_id);
    };

    public composite query func get_vote({ vote_id: UUID }) : async ?SYesNoVote {
        let vote = await Protocol.find_vote({ vote_id; });
        Option.map(vote, func(vote_type: SVoteType) : SYesNoVote {
            with_text(vote_type);
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
            with_text(vote_type);
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

    func with_text(vote_type: SVoteType) : SYesNoVote {
        switch(vote_type){
            case(#YES_NO(vote)) { 
                { vote with text = Map.get<UUID, Text>(_texts, Map.thash, vote.vote_id); };
            };
        };
    };

};