import ProtocolTypes "../protocol/Types";

import Map           "mo:map/Map";
import Set           "mo:map/Set";
import Array         "mo:base/Array";
import Principal     "mo:base/Principal";
import Result        "mo:base/Result";
import Option        "mo:base/Option";
import Iter          "mo:base/Iter";
import Debug         "mo:base/Debug";
import Buffer        "mo:base/Buffer";

import Protocol      "canister:protocol";


shared({ caller = admin }) actor class Backend() = this {

    type YesNoAggregate = ProtocolTypes.YesNoAggregate;
    type YesNoChoice = ProtocolTypes.YesNoChoice;
    type SVoteType = ProtocolTypes.SVoteType;
    type VoteInfo = {
        text: Text;
        visible: Bool;
        category: Text;
    };
    type SYesNoVote = ProtocolTypes.SVote<YesNoAggregate, YesNoChoice> and { info: VoteInfo };
    type Account = ProtocolTypes.Account;
    type UUID = ProtocolTypes.UUID;

    type SNewVoteResult = Result.Result<SYesNoVote, SNewVoteError>;
    type SNewVoteError = ProtocolTypes.NewVoteError or { #AnonymousCaller; #CategoryNotFound; };

    stable let _infos = Map.new<UUID, VoteInfo>();
    stable let _categories = Map.new<Text, Set.Set<UUID>>();

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
                    let info = { text; visible = true; category; };
                    Map.set(_infos, Map.thash, vote.vote_id, info);
                    switch(Map.get(_categories, Map.thash, category)) {
                        case(null){ /* Shall not happen */ };
                        case(?ids) { ignore Set.put(ids, Set.thash, vote.vote_id); };
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

    public composite query func get_votes({ categories: ?[Text]; previous: ?UUID; limit: Nat; }) : async [SYesNoVote] {
        let buffer = Buffer.Buffer<[UUID]>(limit);

        // Collect all vote IDs from the given categories (or all if `categories` is null)
        switch (categories) {
            case (null) { buffer.add(Iter.toArray(Map.keys(_infos))); };
            case (?c) { 
                for (category in Array.vals(c)) {
                    switch (Map.get(_categories, Map.thash, category)) {
                        case (null) { };
                        case (?ids) { buffer.add(Set.toArray(ids)); };
                    };
                };
            };
        };

        // Flatten collected vote IDs into a Set (ordering by UUID)
        let ids = Set.fromIter(Array.vals(Array.flatten(Buffer.toArray(buffer))), Set.thash);

        // Retrieve vote IDs starting from `previous`, if provided
        let iter = Set.keysFrom(ids, Set.thash, previous);
        let filter_ids = Buffer.Buffer<UUID>(limit);

        // Collect up to `limit` vote IDs
        label limit_loop while (filter_ids.size() < limit) {
            switch (iter.next()) {
                case (?id) { filter_ids.add(id); };
                case (null) { break limit_loop; };
            };
        };

        // Fetch votes using the collected `filter_ids`
        let votes = await Protocol.get_votes({ origin = Principal.fromActor(this); filter_ids = ?Buffer.toArray(filter_ids); });

        // Process and return votes
        Array.map(votes, func(vote_type: SVoteType) : SYesNoVote {
            with_info(vote_type);
        });
    };

    public shared func add_categories(categories: [Text]) : async () {
        for (category in Array.vals(categories)) {
            Map.set(_categories, Map.thash, category, Set.new<UUID>());
        };
    };

    public shared func remove_category(category: Text) : async () {
        Map.delete(_categories, Map.thash, category);
    };

    public query func get_categories() : async [Text] {
        Iter.toArray(Map.keys(_categories));
    };

    public query func get_vote_by_category() : async [(Text, [UUID])] {
        var result = Buffer.Buffer<(Text, [UUID])>(Map.size(_categories));

        for ((category, votesSet) in Map.entries(_categories)) {
            let votesArray = Iter.toArray(Set.keys(votesSet));
            result.add((category, votesArray));
        };

        return Buffer.toArray(result);
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