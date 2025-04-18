import Types "Types";
import Timeline "utils/Timeline";
import DebtProcessor "DebtProcessor";
import LockScheduler2 "LockScheduler2";
import ForesightUpdater "ForesightUpdater";
import Yielder "Yielder";
import IterUtils "utils/Iter";
import BallotUtils "votes/BallotUtils";

import Int "mo:base/Int";
import Debug "mo:base/Debug";
import Float "mo:base/Float";
import Option "mo:base/Option";
import Iter "mo:base/Iter";

import Map "mo:map/Map";

module {

    type UUID = Types.UUID;
    type Lock = Types.Lock;
    type YesNoBallot = Types.Ballot<Types.YesNoChoice>;
    type LockRegister = Types.LockRegister;
    type YesNoVote = Types.YesNoVote;
    type DebtRecord = Types.DebtRecord;

    type Map<K, V> = Map.Map<K, V>;
    type Iter<T> = Iter.Iter<T>;

    public class LockScheduler({
        lock_scheduler: LockScheduler2.LockScheduler;
        yielder: Yielder.Yielder;
        foresight_calculator: ForesightUpdater.ForesightUpdater;
        locked_per_vote: Map<UUID, Nat>;
        update_lock_info: (YesNoBallot, Nat) -> ();
        btc_debt: DebtProcessor.DebtProcessor;
        get_ballot: (UUID) -> YesNoBallot;
    }) {

//        // TODO: should not be public but it is required for ballot preview
//        public func refresh_lock_duration(ballot: YesNoBallot, time: Nat) {
//            update_lock_info(ballot, time);
//        };
//
//        // add
//        public func add(new: YesNoBallot, prev: Iter<YesNoBallot>, time: Nat) : async* () {
//
//            // Update the total locked per vote
//            let locked_in_vote = Option.get(Map.get(locked_per_vote, Map.thash, new.vote_id), 0);
//            Map.set(locked_per_vote, Map.thash, new.vote_id, locked_in_vote + new.amount);
//        };
//
//        public func on_unlocked({ removed: Lock; time: Nat; }) {
//
//            // Trigger the transfer of the original amount plus the reward
//            btc_debt.increase_debt({ 
//                id = ballot.ballot_id;
//                account = ballot.from;
//                amount = Float.fromInt(ballot.amount + Timeline.current(ballot.foresight).reward);
//                pending = 0.0;
//                time = removed.release_date;
//            });
//
//            // Update the total locked per vote
//            let locked_in_vote = Option.get(Map.get(locked_per_vote, Map.thash, ballot.vote_id), 0);
//            let diff : Int = locked_in_vote - ballot.amount;
//            if (diff < 0) {
//                Debug.trap("The amount to unlock from the vote is greater than the locked amount");
//            };
//            Map.set(locked_per_vote, Map.thash, ballot.vote_id, Int.abs(diff));
//        };

    };

};