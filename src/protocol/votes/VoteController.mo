import BallotAggregator   "BallotAggregator";
import Types              "../Types";
import RollingTimeline    "../utils/RollingTimeline";
import LockInfoUpdater    "../locks/LockInfoUpdater";
import Decay              "../duration/Decay";
import IterUtils          "../utils/Iter";

import Set                "mo:map/Set";
import Map                "mo:map/Map";
import BTree              "mo:stableheapbtreemap/BTree";

import Debug              "mo:base/Debug";
import Iter               "mo:base/Iter";
import Order              "mo:base/Order";
import Float              "mo:base/Float";
import Int                "mo:base/Int";

module {

    let BTREE_ORDER = 8;

    type Account = Types.Account;
    type UUID = Types.UUID;
    type Vote<A, B> = Types.Vote<A, B>;
    type LimitOrder<B> = Types.LimitOrder<B>;
    type LimitOrderRegister<B> = Types.LimitOrderRegister<B>;
    type LimitOrderBTreeKey = Types.LimitOrderBTreeKey;
    type Ballot<B> = Types.Ballot<B>;
    type LockInfo = Types.LockInfo;
    type Foresight = Types.Foresight;

    type Iter<T> = Map.Iter<T>;
    type BTree<K, V> = BTree.BTree<K, V>;
    type Set<T> = Set.Set<T>;
    type Order = Order.Order;

    public type PutBallotArgs = {
        ballot_id: UUID;
        timestamp: Nat;
        amount: Nat;
        tx_id: Nat;
        supply_index: Float;
        from: Account;
    };

    public type PutLimitOrderArgs<B> = {
        order_id: UUID;
        account: Account;
        amount: Nat;
        choice: B;
        limit_dissent: Float;
        tx_id: Nat;
        supply_index: Float;
        timestamp: Nat;
    };

    type PutBallotSuccess<B> = {
        new: Ballot<B>;
        previous: [Ballot<B>];
    };
   
    public class VoteController<A, B>({
        empty_aggregate: A;
        choice_hash: Map.HashUtils<B>;
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
                aggregate = RollingTimeline.make1h4y(date, empty_aggregate);
                ballots = Set.new<UUID>();
                limit_orders = {
                    register = Map.new<UUID, LimitOrder<B>>();
                    descending_orders_by_choice = Map.new<B, BTree<LimitOrderBTreeKey, UUID>>();
                };
                author;
                var tvl = 0;
            };
        };

        public func put_ballot(vote: Vote<A, B>, choice: B, args: PutBallotArgs) : { new: Ballot<B>; previous: [Ballot<B>] } {

            let { vote_id } = vote;
            let { ballot_id; amount; timestamp; } = args;
            let time = timestamp;

            // TODO: it is too late to check for existing ballot here, the transfer has already happened
            if (Set.has(vote.ballots, Set.thash, ballot_id)) {
                Debug.trap("A ballot with the ID " # args.ballot_id # " already exists");
            };

            let outcome = ballot_aggregator.compute_outcome({ aggregate = vote.aggregate.current.data; choice; amount; time; });
            let aggregate = outcome.aggregate.update;
            let { dissent; consent } = outcome.ballot;

            // Update the vote aggregate
            RollingTimeline.insert(vote.aggregate, timestamp, aggregate);

            // Update the ballot consents because of the new aggregate
            for (ballot in vote_ballots(vote)) {
                RollingTimeline.insert(ballot.consent, timestamp, ballot_aggregator.get_consent({ aggregate; choice = ballot.choice; time; }));
            };

            // Init the new ballot
            let new = init_ballot({vote_id; choice; args; dissent; consent; });
            // Update the hotness of the previous ballots
            lock_info_updater.add(new, vote_ballots(vote), time);

            // Add the ballot to the vote
            add_ballot(ballot_id, new);
            Set.add(vote.ballots, Set.thash, ballot_id);

            // Update TVL by adding the ballot amount
            vote.tvl += amount;

            { new; previous = Iter.toArray(vote_ballots(vote)); };
        };

        public func put_limit_order(vote: Vote<A, B>, args: PutLimitOrderArgs<B>) {

            // TODO: should we check for existing order_id?

            let { order_id; account; amount; choice; limit_dissent; supply_index; tx_id; timestamp; } = args;
            let { register; descending_orders_by_choice } = vote.limit_orders;

            // Store the limit order in the register
            Map.set(register, Map.thash, order_id, {
                order_id;
                account;
                choice;
                limit_dissent;
                var raw_amount = amount;
                supply_index;
                tx_id;
                timestamp;
            });

            // Get or create the descending orders btree for that choice
            let descending_orders = switch(Map.get(descending_orders_by_choice, choice_hash, choice)){
                case(null) {
                    let btree = BTree.init<LimitOrderBTreeKey, UUID>(?BTREE_ORDER);
                    Map.set(descending_orders_by_choice, choice_hash, choice, btree);
                    btree;
                };
                case(?(btree)) { btree; };
            };

            // Insert the order in the descending orders btree
            let key = { limit_dissent; timestamp };
            ignore BTree.insert(descending_orders, func(a: LimitOrderBTreeKey, b: LimitOrderBTreeKey) : Order {
                // First compare by limit_dissent descending
                switch(Float.compare(b.limit_dissent, a.limit_dissent)){
                    case(#less) { #less; };
                    case(#greater) { #greater; };
                    case(#equal) {
                        // Then compare by timestamp ascending
                        Int.compare(a.timestamp, b.timestamp);
                    };
                };
            }, key, order_id);
        };

        public func unlock_ballot(vote: Vote<A, B>, ballot_id: UUID) {
            // Just update the TVL
            let ballot = get_ballot(ballot_id);
            vote.tvl -= ballot.amount;
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
                    supply_index = ballot.supply_index;
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
                consent = RollingTimeline.make1h4y<Float>(timestamp, consent);
                decay = decay_model.compute_decay(timestamp);
                var foresight : Foresight = { reward = 0; apr = { current = 0.0; potential = 0.0; }; };
                var hotness = 0.0;
                var lock : ?LockInfo = null;
            };
            ballot;
        };

    };

};
