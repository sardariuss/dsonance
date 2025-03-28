import BallotAggregator   "BallotAggregator";
import Types              "../Types";
import Timeline           "../utils/Timeline";
import HotMap             "../locks/HotMap";
import Decay              "../duration/Decay";

import Set                "mo:map/Set";

import Debug              "mo:base/Debug";
import Iter               "mo:base/Iter";

module {

    type Account = Types.Account;
    type UUID = Types.UUID;
    type Vote<A, B> = Types.Vote<A, B>;
    type Ballot<B> = Types.Ballot<B>;
    type LockInfo = Types.LockInfo;
    type Foresight = Types.Foresight;

    type Iter<T> = Iter.Iter<T>;

    public type PutBallotArgs = {
        ballot_id: UUID;
        timestamp: Nat;
        amount: Nat;
        tx_id: Nat;
        from: Account;
    };
   
    public class VoteController<A, B>({
        empty_aggregate: A;
        ballot_aggregator: BallotAggregator.BallotAggregator<A, B>;
        decay_model: Decay.DecayModel;
        hot_map: HotMap.HotMap;
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
                last_mint = date;
                origin;
                aggregate = Timeline.initialize(date, empty_aggregate);
                ballots = Set.new<UUID>();
                author;
            };
        };

        public func preview_ballot(vote: Vote<A, B>, choice: B, args: PutBallotArgs) : Ballot<B> {

            let { vote_id } = vote;
            let { amount; timestamp; } = args;
            let time = timestamp;
            
            let outcome = ballot_aggregator.compute_outcome({ aggregate = vote.aggregate.current.data; choice; amount; time; });
            let { dissent; consent } = outcome.ballot;

            let ballot = init_ballot({vote_id; choice; args; dissent; consent; });
            hot_map.add_new({ iter = vote_ballots(vote); elem = ballot; update_previous = false; });

            ballot;
        };

        public func put_ballot(vote: Vote<A, B>, choice: B, args: PutBallotArgs) : Ballot<B> {

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

            // Update the hotness
            let ballot = init_ballot({vote_id; choice; args; dissent; consent; });
            hot_map.add_new({ iter = vote_ballots(vote); elem = ballot; update_previous = true; });

            // Add the ballot
            add_ballot(ballot_id, ballot);
            Set.add(vote.ballots, Set.thash, ballot_id);

            ballot;
        };

        public func vote_ballots(vote: Vote<A, B>) : Iter<Ballot<B>> {
            let it = Set.keys(vote.ballots);
            func next() : ?(Ballot<B>) {
                label get_next while(true) {
                    switch(it.next()){
                        case(null) { break get_next; };
                        case(?id) { 
                            return ?get_ballot(id);
                        };
                    };
                };
                null;
            };
            return { next };
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
                foresight = Timeline.initialize<Foresight>(timestamp, { reward = 0; apr = { current = 0.0; potential = 0.0; }; });
                decay = decay_model.compute_decay(timestamp);
                var hotness = 0.0;
                var lock : ?LockInfo = null;
            };
            ballot;
        };

    };

};
