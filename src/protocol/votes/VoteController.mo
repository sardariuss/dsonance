import BallotAggregator   "BallotAggregator";
import Types              "../Types";
import Timeline           "../utils/Timeline";
import LockInfoUpdater    "../locks/LockInfoUpdater";
import Decay              "../duration/Decay";
import IterUtils          "../utils/Iter";

import Set                "mo:map/Set";
import Map                "mo:map/Map";

import Debug              "mo:base/Debug";
import Iter               "mo:base/Iter";

module {

    type Account = Types.Account;
    type UUID = Types.UUID;
    type Vote<A, B> = Types.Vote<A, B>;
    type Ballot<B> = Types.Ballot<B>;
    type LockInfo = Types.LockInfo;
    type Foresight = Types.Foresight;

    type Iter<T> = Map.Iter<T>;

    public type PutBallotArgs = {
        ballot_id: UUID;
        timestamp: Nat;
        amount: Nat;
        tx_id: Nat;
        from: Account;
    };

    type PutBallotSuccess<B> = {
        new: Ballot<B>;
        previous: [Ballot<B>];
    };
   
    public class VoteController<A, B>({
        empty_aggregate: A;
        ballot_aggregator: BallotAggregator.BallotAggregator<A, B>;
        decay_model: Decay.DecayModel;
        lock_info_updater: LockInfoUpdater.LockInfoUpdater;
        get_ballot: UUID -> Ballot<B>;
        add_ballot: (UUID, Ballot<B>) -> ();
    }){

        public func new_vote({
            vote_id: UUID;
            tx_id: Nat;
            date: Nat;
            origin: Principal;
            author: Account;
        }) : Vote<A, B> {
            {
                vote_id;
                tx_id;
                date;
                origin;
                aggregate = Timeline.initialize(date, empty_aggregate);
                ballots = Set.new<UUID>();
                author;
                var tvl = 0;
            };
        };

        public func put_ballot(vote: Vote<A, B>, choice: B, args: PutBallotArgs) : { new: Ballot<B>; previous: [Ballot<B>] } {

            let { vote_id } = vote;
            let { ballot_id; amount; timestamp; } = args;
            let time = timestamp;

            if (Set.has(vote.ballots, Set.thash, ballot_id)) {
                Debug.trap("A ballot with the ID " # args.ballot_id # " already exists");
            };

            let outcome = ballot_aggregator.compute_outcome({ aggregate = vote.aggregate.current.data; choice; amount; time; });
            let aggregate = outcome.aggregate.update;
            let { dissent; consent } = outcome.ballot;

            // Update the vote aggregate
            Timeline.insert(vote.aggregate, timestamp, aggregate);

            // Update the ballot consents because of the new aggregate
            for (ballot in vote_ballots(vote)) {
                Timeline.insert(ballot.consent, timestamp, ballot_aggregator.get_consent({ aggregate; choice = ballot.choice; time; }));
            };

            // Init the new ballot
            let new = init_ballot({vote_id; choice; args; dissent; consent; });
            // Update the hotness of the previous ballots
            lock_info_updater.add(new, vote_ballots(vote), time);

            // Add the ballot to the vote
            add_ballot(ballot_id, new);
            Set.add(vote.ballots, Set.thash, ballot_id);

            { new; previous = Iter.toArray(vote_ballots(vote)); };
        };

        public func vote_ballots(vote: Vote<A, B>) : Iter<Ballot<B>> {
            IterUtils.map(Set.keys(vote.ballots), get_ballot);
        };

        public func vote_ballots_copy(vote: Vote<A, B>) : Iter<Ballot<B>> {
            let copy_ballot = func(ballot_id: UUID): Ballot<B> {
                let ballot = get_ballot(ballot_id);
                return {
                    ballot_id = ballot.ballot_id;
                    vote_id = ballot.vote_id;
                    timestamp = ballot.timestamp;
                    choice = ballot.choice;
                    amount = ballot.amount;
                    dissent = ballot.dissent;
                    consent = ballot.consent;
                    tx_id = ballot.tx_id;
                    from = ballot.from;
                    decay = ballot.decay;
                    var foresight = ballot.foresight;
                    var hotness = ballot.hotness;
                    var lock = ballot.lock;
                };
            };
            IterUtils.map(Set.keys(vote.ballots), copy_ballot);
        };

        func init_ballot({
            vote_id: UUID;
            choice: B;
            args: PutBallotArgs;
            dissent: Float;
            consent: Float;
        }) : Ballot<B> {
            let { timestamp; } = args;

            let ballot : Ballot<B> = {
                args with
                vote_id;
                choice;
                dissent;
                consent = Timeline.initialize<Float>(timestamp, consent);
                decay = decay_model.compute_decay(timestamp);
                var foresight : Foresight = { reward = 0; apr = { current = 0.0; potential = 0.0; }; };
                var hotness = 0.0;
                var lock : ?LockInfo = null;
            };
            ballot;
        };

    };

};
