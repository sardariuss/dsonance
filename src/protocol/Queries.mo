import Types       "Types";
import MapUtils    "utils/Map";
import Clock       "utils/Clock";
import BallotUtils "votes/BallotUtils";

import Map         "mo:map/Map";
import Set         "mo:map/Set";

import Option      "mo:base/Option";
import Buffer      "mo:base/Buffer";
import Iter        "mo:base/Iter";

module {

    type Time = Nat;
    type VoteRegister = Types.VoteRegister;
    type VoteType = Types.VoteType;
    type BallotType = Types.BallotType;
    type Account = Types.Account;
    type UUID = Types.UUID;
    type BallotRegister = Types.BallotRegister;
    type Iter<T> = Iter.Iter<T>;

    public class Queries({
        clock: Clock.Clock;
        vote_register: VoteRegister;
        ballot_register: BallotRegister;
    }){

        public func get_ballots({ account: Account; previous: ?UUID; limit: Nat; filter_active: Bool; }) : [BallotType] {
            let buffer = Buffer.Buffer<BallotType>(limit);
            Option.iterate(Map.get(ballot_register.by_account, MapUtils.acchash, account), func(ids: Set.Set<UUID>) {
                let iter = Set.keysFrom(ids, Set.thash, previous);
                label limit_loop while (buffer.size() < limit) {
                    switch (iter.next()) {
                        case (null) { break limit_loop; };
                        case (?id) { 
                            Option.iterate(Map.get(ballot_register.ballots, Map.thash, id), func(ballot_type: BallotType) {
                                if (filter_active) {
                                    switch(ballot_type){
                                        case(#YES_NO(ballot)) {
                                            let lock = BallotUtils.unwrap_lock(ballot);
                                            if (lock.release_date > clock.get_time()){
                                                buffer.add(ballot_type);
                                            };
                                        };
                                    };
                                } else {
                                    buffer.add(ballot_type);
                                };
                            });
                        };
                    };
                };
            }); 
            Buffer.toArray(buffer);
        };

        public func get_locked_amount({ account: Account; }) : Nat {
            let timestamp = clock.get_time();
            switch(Map.get(ballot_register.by_account, MapUtils.acchash, account)){
                case(null) { 0; };
                case(?ids) { 
                    var total = 0;
                    for (ballot_id in Set.keys(ids)){
                        switch(Map.get(ballot_register.ballots, Map.thash, ballot_id)){
                            case(null) {};
                            case(?ballot) {
                                switch(ballot){
                                    case(#YES_NO(b)) {
                                        let lock = BallotUtils.unwrap_lock(b);
                                        if (lock.release_date > timestamp){
                                            total += b.amount;
                                        };
                                    };
                                };
                            };
                        };
                    };
                    total;
                };
            };
        };

        public func get_votes({origin: Principal; filter_ids: ?[UUID]}) : [VoteType] {
            
            let vote_ids = Option.get(Map.get(vote_register.by_origin, Map.phash, origin), Set.new<UUID>());
            let filter = Option.map(filter_ids, func(ids: [UUID]) : Set.Set<UUID> { Set.fromIter(Iter.fromArray(ids), Set.thash) });
            
            Set.toArrayMap(vote_ids, func(vote_id: UUID) : ?VoteType {
                switch(filter){
                    case(null) {};
                    case(?filter) {
                        if (not Set.has(filter, Set.thash, vote_id)){
                            return null;
                        };
                    };
                };
                Map.get(vote_register.votes, Map.thash, vote_id);
            });
        };

        public func get_votes_by_author({ author: Account; previous: ?UUID; limit: Nat; }) : [VoteType] {
            let buffer = Buffer.Buffer<VoteType>(limit);
            Option.iterate(Map.get(vote_register.by_author, MapUtils.acchash, author), func(ids: Set.Set<UUID>) {
                let iter = Set.keysFrom(ids, Set.thash, previous);
                label limit_loop while (buffer.size() < limit) {
                    switch (iter.next()) {
                        case (null) { break limit_loop; };
                        case (?id) { 
                            Option.iterate(Map.get(vote_register.votes, Map.thash, id), func(vote_type: VoteType) {
                                buffer.add(vote_type);
                            });
                        };
                    };
                };
            }); 
            Buffer.toArray(buffer);
        };

    };

};