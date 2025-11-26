import PositionAggregator   "PositionAggregator";
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

    // TODO: is it the right place for this constant?
    let BTREE_ORDER = 8;

    type Account = Types.Account;
    type UUID = Types.UUID;
    type Pool<A, C> = Types.Pool<A, C>;
    type Position<C> = Types.Position<C>;
    type LockInfo = Types.LockInfo;
    type Foresight = Types.Foresight;
    type LimitOrder<C> = Types.LimitOrder<C>;
    type LimitOrderBTreeKey = Types.LimitOrderBTreeKey;

    type Iter<T> = Map.Iter<T>;
    type BTree<K, V> = BTree.BTree<K, V>;
    type Set<T> = Set.Set<T>;
    type Order = Order.Order;

    public type PutPositionArgs = {
        position_id: UUID;
        timestamp: Nat;
        amount: Nat;
        tx_id: Nat;
        supply_index: Float;
        from: Account;
    };

    type PutPositionSuccess<C> = {
        new: Position<C>;
        previous: [Position<C>];
    };

    public type PutLimitOrderArgs<C> = {
        order_id: UUID;
        choice: C;
        limit_dissent: Float;
        timestamp: Nat;
    };
   
    public class PoolController<A, C>({
        empty_aggregate: A;
        choice_hash: Map.HashUtils<C>;
        position_aggregator: PositionAggregator.PositionAggregator<A, C>;
        decay_model: Decay.DecayModel;
        lock_info_updater: LockInfoUpdater.LockInfoUpdater;
        get_position: UUID -> Position<C>;
        add_position: (UUID, Position<C>) -> ();
    }){

        public func new_pool({
            pool_id: UUID;
            tx_id: Nat;
            date: Nat;
            origin: Principal;
            author: Account;
        }) : Pool<A, C> {
            {
                pool_id;
                tx_id;
                date;
                origin;
                aggregate = RollingTimeline.make1h4y(date, empty_aggregate);
                descending_orders = Map.new<C, BTree<LimitOrderBTreeKey, UUID>>();
                positions = Set.new<UUID>();
                author;
                var tvl = 0;
            };
        };

        public func put_position(pool: Pool<A, C>, choice: C, args: PutPositionArgs) : { new: Position<C>; previous: [Position<C>] } {

            let { pool_id } = pool;
            let { position_id; amount; timestamp; } = args;
            let time = timestamp;

            // TODO: it is too late to check for existing ballot here, the transfer has already happened
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

        public func put_limit_order(pool: Pool<A, C>, args: PutLimitOrderArgs<C>) {

            // TODO: should we check for existing order_id?

            let { order_id; choice; limit_dissent; timestamp; } = args;

            // Get or create the descending orders btree for that choice
            let descending_orders = switch(Map.get(pool.descending_orders, choice_hash, choice)){
                case(null) {
                    let btree = BTree.init<LimitOrderBTreeKey, UUID>(?BTREE_ORDER);
                    Map.set(pool.descending_orders, choice_hash, choice, btree);
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

        public func unlock_position(pool: Pool<A, C>, position_id: UUID) {
            // Just update the TVL
            let position = get_position(position_id);
            pool.tvl -= position.amount;
        };

        public func pool_positions(pool: Pool<A, C>) : Iter<Position<C>> {
            IterUtils.map(Set.keys(pool.positions), get_position);
        };

        public func pool_positions_copy(pool: Pool<A, C>) : Iter<Position<C>> {
            let copy_position = func(position_id: UUID): Position<C> {
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
            choice: C;
            args: PutPositionArgs;
            dissent: Float;
            consent: Float;
        }) : Position<C> {
            let { timestamp; } = args;

            let position : Position<C> = {
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
