import Types       "Types";
import MapUtils    "utils/Map";
import Clock       "utils/Clock";
import BallotUtils "votes/BallotUtils";
import SharedConversions "shared/SharedConversions";

import Map         "mo:map/Map";
import Set         "mo:map/Set";

import Option      "mo:base/Option";
import Buffer      "mo:base/Buffer";
import Iter        "mo:base/Iter";
import Debug       "mo:base/Debug";
import Float       "mo:base/Float";

module {

    type Time = Nat;
    type VoteRegister = Types.VoteRegister;
    type VoteType = Types.VoteType;
    type BallotType = Types.BallotType;
    type SBallotType = Types.SBallotType;
    type SVoteType = Types.SVoteType;
    type Account = Types.Account;
    type UUID = Types.UUID;
    type YesNoVote = Types.YesNoVote;
    type BallotRegister = Types.BallotRegister;
    type DebtRegister = Types.DebtRegister;
    type Iter<T> = Iter.Iter<T>;
    type DebtInfo = Types.DebtInfo;
    type SDebtInfo = Types.SDebtInfo;
    type DebtRecord = Types.DebtRecord;
    type State = Types.State;
    type Parameters = Types.Parameters;
    type UserSupply = Types.UserSupply;
    type STimeline<T> = Types.STimeline<T>;
    type LendingIndex = Types.LendingIndex;
    type QueryDirection = Types.QueryDirection;

    public class Queries({
        clock: Clock.Clock;
        state: State; 
    }){

        public func get_ballots({ account: Account; previous: ?UUID; limit: Nat; filter_active: Bool; direction: QueryDirection; }) : [SBallotType] {
            let buffer = Buffer.Buffer<SBallotType>(limit);
            Option.iterate(Map.get(state.ballot_register.by_account, MapUtils.acchash, account), func(ids: Set.Set<UUID>) {
                let iter = Set.keysFrom(ids, Set.thash, previous);
                label limit_loop while (buffer.size() < limit) {
                    let next_id = switch(direction) {
                        case(#forward) { iter.next(); };
                        case(#backward) { iter.prev(); };
                    };
                    switch (next_id) {
                        case (null) { break limit_loop; };
                        case (?id) {
                            Option.iterate(Map.get(state.ballot_register.ballots, Map.thash, id), func(ballot_type: BallotType) {
                                switch(ballot_type){
                                    case(#YES_NO(ballot)) {
                                        let lock = BallotUtils.unwrap_lock_info(ballot);
                                        if (filter_active and lock.release_date >= clock.get_time()){
                                            buffer.add(SharedConversions.shareBallotType(ballot_type));
                                        } else if (not filter_active and lock.release_date < clock.get_time()) {
                                            buffer.add(SharedConversions.shareBallotType(ballot_type));
                                        };
                                    };
                                };
                            });
                        };
                    };
                };
            });

            Buffer.toArray(buffer);
        };

        public func find_ballot(ballot_id: UUID) : ?SBallotType {
            Option.map<BallotType, SBallotType>(Map.get(state.ballot_register.ballots, Map.thash, ballot_id), SharedConversions.shareBallotType);
        };

        public func find_vote(vote_id: UUID) : ?SVoteType {
            Option.map<VoteType, SVoteType>(Map.get(state.vote_register.votes, Map.thash, vote_id), SharedConversions.shareVoteType);
        };

        public func get_user_supply({ account: Account; }) : UserSupply {
            let timestamp = clock.get_time();
            switch(Map.get(state.ballot_register.by_account, MapUtils.acchash, account)){
                case(null) {};
                case(?ids) { 
                    var amount = 0;
                    var sum_apr = 0.0;
                    for (ballot_id in Set.keys(ids)){
                        switch(Map.get(state.ballot_register.ballots, Map.thash, ballot_id)){
                            case(null) {};
                            case(?ballot) {
                                switch(ballot){
                                    case(#YES_NO(b)) {
                                        let lock = BallotUtils.unwrap_lock_info(b);
                                        if (lock.release_date > timestamp){
                                            amount += b.amount;
                                            sum_apr += (b.foresight.apr.current * Float.fromInt(b.amount));
                                        };
                                    };
                                };
                            };
                        };
                    };
                    if (amount > 0){
                        return { amount; apr = sum_apr / Float.fromInt(amount); };
                    };
                };
            };
            return { amount = 0; apr = 0.0; }; 
        };

        public func get_votes({origin: Principal; previous: ?UUID; limit: Nat; direction: QueryDirection;}) : [SVoteType] {
            let buffer = Buffer.Buffer<VoteType>(limit);
            Option.iterate(Map.get(state.vote_register.by_origin, Map.phash, origin), func(ids: Set.Set<UUID>) {
                let iter = Set.keysFrom(ids, Set.thash, previous);
                label limit_loop while (buffer.size() < limit) {
                    let next_id = switch(direction) {
                        case(#forward) { iter.next(); };
                        case(#backward) { iter.prev(); };
                    };
                    switch (next_id) {
                        case (null) { break limit_loop; };
                        case (?id) {
                            Option.iterate(Map.get(state.vote_register.votes, Map.thash, id), func(vote_type: VoteType) {
                                buffer.add(vote_type);
                            });
                        };
                    };
                };
            });
            Buffer.toArray(Buffer.map<VoteType, SVoteType>(buffer, SharedConversions.shareVoteType));
        };

        public func get_votes_by_author({ author: Account; previous: ?UUID; limit: Nat; direction: QueryDirection; }) : [SVoteType] {
            let buffer = Buffer.Buffer<VoteType>(limit);
            Option.iterate(Map.get(state.vote_register.by_author, MapUtils.acchash, author), func(ids: Set.Set<UUID>) {
                let iter = Set.keysFrom(ids, Set.thash, previous);
                label limit_loop while (buffer.size() < limit) {
                    let next_id = switch(direction) {
                        case(#forward) { iter.next(); };
                        case(#backward) { iter.prev(); };
                    };
                    switch (next_id) {
                        case (null) { break limit_loop; };
                        case (?id) {
                            Option.iterate(Map.get(state.vote_register.votes, Map.thash, id), func(vote_type: VoteType) {
                                buffer.add(vote_type);
                            });
                        };
                    };
                };
            });
            Buffer.toArray(Buffer.map<VoteType, SVoteType>(buffer, SharedConversions.shareVoteType));
        };

        public func get_vote_ballots(vote_id: UUID) : [SBallotType] {
            let vote = switch(Map.get(state.vote_register.votes, Map.thash, vote_id)){
                case(null) { return []; };
                case(?#YES_NO(v)) { v; };
            };
            let buffer = Buffer.Buffer<SBallotType>(0);
            for (id in Set.keys(vote.ballots)){
                switch(Map.get(state.ballot_register.ballots, Map.thash, id)){
                    case(null) { Debug.trap("Ballot not found"); };
                    case(?ballot) {
                        buffer.add(SharedConversions.shareBallotType(ballot));
                    };
                };
            };
            Buffer.toArray(buffer);
        };

        public func get_parameters() : Parameters {
            state.parameters;
        };

        public func get_lending_index() : STimeline<LendingIndex> {
            SharedConversions.shareTimeline(state.lending.index);
        };

    };

};