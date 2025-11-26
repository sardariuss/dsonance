import PositionAggregator   "PositionAggregator";
import Types              "../Types";
import RollingTimeline    "../utils/RollingTimeline";
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
    type Pool<A, B> = Types.Pool<A, B>;
    type Position<B> = Types.Position<B>;
    type LockInfo = Types.LockInfo;
    type Foresight = Types.Foresight;

    type Iter<T> = Map.Iter<T>;

    public type PutPositionArgs = {
        position_id: UUID;
        timestamp: Nat;
        amount: Nat;
        tx_id: Nat;
        supply_index: Float;
        from: Account;
    };

    type PutPositionSuccess<B> = {
        new: Position<B>;
        previous: [Position<B>];
    };
   
    public class PoolController<A, B>({
        empty_aggregate: A;
        position_aggregator: PositionAggregator.PositionAggregator<A, B>;
        decay_model: Decay.DecayModel;
        lock_info_updater: LockInfoUpdater.LockInfoUpdater;
        get_position: UUID -> Position<B>;
        add_position: (UUID, Position<B>) -> ();
    }){

        public func new_pool({
            pool_id: UUID;
            tx_id: Nat;
            date: Nat;
            origin: Principal;
            author: Account;
        }) : Pool<A, B> {
            {
                pool_id;
                tx_id;
                date;
                origin;
                aggregate = RollingTimeline.make1h4y(date, empty_aggregate);
                positions = Set.new<UUID>();
                author;
                var tvl = 0;
            };
        };

        public func put_position(pool: Pool<A, B>, choice: B, args: PutPositionArgs) : { new: Position<B>; previous: [Position<B>] } {

            let { pool_id } = pool;
            let { position_id; amount; timestamp; } = args;
            let time = timestamp;

            if (Set.has(pool.positions, Set.thash, position_id)) {
                Debug.trap("A position with the ID " # args.position_id # " already exists");
            };

            let outcome = position_aggregator.compute_outcome({ aggregate = pool.aggregate.current.data; choice; amount; time; });
            let aggregate = outcome.aggregate.update;
            let { dissent; consent } = outcome.position;

            // Update the pool aggregate
            RollingTimeline.insert(pool.aggregate, timestamp, aggregate);

            // Update the position consents because of the new aggregate
            for (position in pool_positions(pool)) {
                RollingTimeline.insert(position.consent, timestamp, position_aggregator.get_consent({ aggregate; choice = position.choice; time; }));
            };

            // Init the new position
            let new = init_position({pool_id; choice; args; dissent; consent; });
            // Update the hotness of the previous positions
            lock_info_updater.add(new, pool_positions(pool), time);

            // Add the position to the pool
            add_position(position_id, new);
            Set.add(pool.positions, Set.thash, position_id);

            // Update TVL by adding the position amount
            pool.tvl += amount;

            { new; previous = Iter.toArray(pool_positions(pool)); };
        };

        public func unlock_position(pool: Pool<A, B>, position_id: UUID) {
            // Just update the TVL
            let position = get_position(position_id);
            pool.tvl -= position.amount;
        };

        public func pool_positions(pool: Pool<A, B>) : Iter<Position<B>> {
            IterUtils.map(Set.keys(pool.positions), get_position);
        };

        public func pool_positions_copy(pool: Pool<A, B>) : Iter<Position<B>> {
            let copy_position = func(position_id: UUID): Position<B> {
                let position = get_position(position_id);
                return {
                    position_id = position.position_id;
                    pool_id = position.pool_id;
                    timestamp = position.timestamp;
                    choice = position.choice;
                    amount = position.amount;
                    dissent = position.dissent;
                    consent = position.consent;
                    tx_id = position.tx_id;
                    supply_index = position.supply_index;
                    from = position.from;
                    decay = position.decay;
                    var foresight = position.foresight;
                    var hotness = position.hotness;
                    var lock = position.lock;
                };
            };
            IterUtils.map(Set.keys(pool.positions), copy_position);
        };

        func init_position({
            pool_id: UUID;
            choice: B;
            args: PutPositionArgs;
            dissent: Float;
            consent: Float;
        }) : Position<B> {
            let { timestamp; } = args;

            let position : Position<B> = {
                args with
                pool_id;
                choice;
                dissent;
                consent = RollingTimeline.make1h4y<Float>(timestamp, consent);
                decay = decay_model.compute_decay(timestamp);
                var foresight : Foresight = { reward = 0; apr = { current = 0.0; potential = 0.0; }; };
                var hotness = 0.0;
                var lock : ?LockInfo = null;
            };
            position;
        };

    };

};
