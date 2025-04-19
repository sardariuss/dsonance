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
import Array       "mo:base/Array";
import Debug       "mo:base/Debug";

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

    public class Queries({
        clock: Clock.Clock;
        vote_register: VoteRegister;
        ballot_register: BallotRegister;
        dsn_debt_register: DebtRegister;
    }){

        public func get_ballots({ account: Account; previous: ?UUID; limit: Nat; filter_active: Bool; }) : [SBallotType] {
            let buffer = Buffer.Buffer<SBallotType>(limit);
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
                                            let lock = BallotUtils.unwrap_lock_info(ballot);
                                            if (lock.release_date > clock.get_time()){
                                                buffer.add(SharedConversions.shareBallotType(ballot_type));
                                            };
                                        };
                                    };
                                } else {
                                    buffer.add(SharedConversions.shareBallotType(ballot_type));
                                };
                            });
                        };
                    };
                };
            }); 

            Buffer.toArray(buffer);
        };

        public func find_ballot(ballot_id: UUID) : ?SBallotType {
            Option.map<BallotType, SBallotType>(Map.get(ballot_register.ballots, Map.thash, ballot_id), SharedConversions.shareBallotType);
        };

        public func find_vote(vote_id: UUID) : ?SVoteType {
            Option.map<VoteType, SVoteType>(Map.get(vote_register.votes, Map.thash, vote_id), SharedConversions.shareVoteType);
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
                                        let lock = BallotUtils.unwrap_lock_info(b);
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

        public func get_votes({origin: Principal; previous: ?UUID; limit: Nat;}) : [SVoteType] {
            let buffer = Buffer.Buffer<VoteType>(limit);
            Option.iterate(Map.get(vote_register.by_origin, Map.phash, origin), func(ids: Set.Set<UUID>) {
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
            Buffer.toArray(Buffer.map<VoteType, SVoteType>(buffer, SharedConversions.shareVoteType));
        };

        public func get_votes_by_author({ author: Account; previous: ?UUID; limit: Nat; }) : [SVoteType] {
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
            Buffer.toArray(Buffer.map<VoteType, SVoteType>(buffer, SharedConversions.shareVoteType));
        };

        public func get_mined_by_author({ author: Account }) : DebtRecord {
            var total_mined = { earned = 0.0; pending = 0.0; };
            let opened_ids = Option.get(Map.get(vote_register.by_author, MapUtils.acchash, author), Set.new<UUID>());
            for (vote_id in Set.keys(opened_ids)){
                switch(Map.get(dsn_debt_register.debts, Map.thash, vote_id)){
                    case(null) { Debug.trap("Debt not found"); };
                    case(?debt) {
                        total_mined := {
                            earned = total_mined.earned + debt.amount.current.data.earned;
                            pending = total_mined.pending + debt.amount.current.data.pending;
                        };
                    };
                };
            };
            total_mined;
        };

        public func get_vote_ballots(vote_id: UUID) : [SBallotType] {
            let vote = switch(Map.get(vote_register.votes, Map.thash, vote_id)){
                case(null) { return []; };
                case(?#YES_NO(v)) { v; };
            };
            let buffer = Buffer.Buffer<SBallotType>(0);
            for (id in Set.keys(vote.ballots)){
                switch(Map.get(ballot_register.ballots, Map.thash, id)){
                    case(null) { Debug.trap("Ballot not found"); };
                    case(?ballot) {
                        buffer.add(SharedConversions.shareBallotType(ballot));
                    };
                };
            };
            Buffer.toArray(buffer);
        };

        public func get_debt_info(debt_id: UUID) : ?Types.SDebtInfo {
            Option.map<DebtInfo, SDebtInfo>(Map.get(dsn_debt_register.debts, Map.thash, debt_id), SharedConversions.shareDebtInfo);
        };

        public func get_debt_infos(ids: [UUID]) : [SDebtInfo] {
            Array.mapFilter<UUID, SDebtInfo>(ids, func(id: UUID) : ?SDebtInfo {
                Option.map<DebtInfo, SDebtInfo>(Map.get(dsn_debt_register.debts, Map.thash, id), SharedConversions.shareDebtInfo);
            });
        };

    };

};