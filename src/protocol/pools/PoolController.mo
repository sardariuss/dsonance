import PositionAggregator   "PositionAggregator";
import Types              "../Types";
import RollingTimeline    "../utils/RollingTimeline";
import LockInfoUpdater    "../locks/LockInfoUpdater";
import Decay              "../duration/Decay";
import IterUtils          "../utils/Iter";

import Set                "mo:map/Set";
import Map                "mo:map/Map";
import BTree              "mo:stableheapbtreemap/BTree";

import Iter               "mo:base/Iter";
import Order              "mo:base/Order";
import Float              "mo:base/Float";
import Int                "mo:base/Int";
import Buffer             "mo:base/Buffer";

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
        account: Account;
        timestamp: Nat;
        choice: C;
        limit_consensus: Float;
        amount: Nat;
    };
   
    public class PoolController<A, C>({
        empty_aggregate: A;
        choice_hash: Map.HashUtils<C>;
        position_aggregator: PositionAggregator.PositionAggregator<A, C>;
        decay_model: Decay.DecayModel;
        lock_info_updater: LockInfoUpdater.LockInfoUpdater;
        get_position: UUID -> Position<C>;
        add_position: (UUID, Position<C>) -> ();
        get_order: UUID -> LimitOrder<C>;
        add_order: (UUID, LimitOrder<C>) -> ();
        delete_order: UUID -> ();
        generate_uuid: () -> Text;
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

        // New version of put_position that take into account the limit orders
        public func put_position(pool: Pool<A, C>, choice: C, args: PutPositionArgs) : { new: Position<C>; previous: [Position<C>] } {
            let { pool_id } = pool;
            let { amount; timestamp; } = args;
            let time = timestamp;
            let decay = decay_model.compute_decay(timestamp);

            var amount_left = Float.fromInt(amount);
            var total_dissent = 0.0;
            var position_consent = 0.0;

            var new_aggregate = pool.aggregate.current.data;
            let new_positions = Buffer.Buffer<Position<C>>(0);

            let descending_orders = get_descending_orders(pool, choice);

            label iter_orders for((key, order_id) in BTree.entries(descending_orders)) {
                let order = get_order(order_id);
                
                // 1. Fill the resistance to reach the limit consensus of the order

                // Compute the resistance to reach to this order
                let resistance = position_aggregator.get_resistance({ aggregate = new_aggregate; choice; target_consensus = order.limit_consensus; time; });
                var to_take = Float.min(amount_left, resistance);

                // Update the aggregate and total dissent
                // @order: do not cast to Int here, should be done in Float
                let position_outcome = position_aggregator.compute_outcome({ aggregate = new_aggregate; choice; amount = Int.abs(Float.toInt(to_take)); time; });
                new_aggregate := position_outcome.aggregate.update;
                total_dissent += position_outcome.position.dissent * to_take;
                position_consent := position_outcome.position.consent;
                
                // Update the amount_left, stop if fully used
                amount_left -= to_take;
                if (amount_left <= 0.0) {
                    break iter_orders;
                };

                // 2. Fill the order as much as possible

                // With choice = NO, limit_consensus = 0.9, order.amount = 100
                //  -> Worth = (0.9 / 0.1) * 100 = 900.0
                // With choice = NO, limit_consensus = 0.9, order.amount = 30
                //  -> Worth = (0.9 / 0.1) * 30 = 270.0
                let opposite_worth = position_aggregator.get_opposite_worth({ aggregate = new_aggregate; choice = order.choice; amount = order.amount; time; });
                // With amount_left = 500, opposite_worth = 900.0
                //  -> to_take = min(500, 900) = 500
                // With amount_left = 500, opposite_worth = 270.0
                //  -> to_take = min(500, 270) = 270
                to_take := Float.min(amount_left, opposite_worth);
                // With to_take = 500, opposite_worth = 900.0
                //  -> order.amount = 100 - (500 / 900) * 100 = 44.44
                // With to_take = 270, opposite_worth = 270.0
                //  -> order.amount = 30 - (270 / 270) * 30 = 0.0
                order.amount -= to_take / opposite_worth * order.amount;
                // Update the amount_left
                amount_left -= to_take;

                // Use 0 as amount because the execution of the limit order does not change the aggregate
                let { dissent; consent; } = position_aggregator.compute_outcome({ aggregate = new_aggregate; choice = order.choice; amount = 0; time; }).position;
                new_positions.add({
                    position_id = generate_uuid();
                    pool_id;
                    timestamp;
                    choice = order.choice;
                    amount = Int.abs(Float.toInt(to_take));
                    dissent;
                    tx_id = 0; // @order
                    supply_index = args.supply_index;
                    from = order.account;
                    decay;
                    var consent = consent;
                    var foresight : Foresight = { reward = 0; apr = { current = 0.0; potential = 0.0; }; };
                    var hotness = 0.0;
                    var lock : ?LockInfo = null;
                });
                
                if (order.amount <= 0.0) {
                    // The position covered the full order
                    ignore BTree.delete(descending_orders, compare_keys, key);
                    delete_order(order_id);
                };

                if (amount_left <= 0.0) {
                    break iter_orders;
                };
            };

            if (amount_left > 0.0) {
                // There is still some position left to put without limit order
                // @order: do not cast to Int here, should be done in Float
                let outcome = position_aggregator.compute_outcome({ aggregate = new_aggregate; choice; amount = Int.abs(Float.toInt(amount_left)); time; });
                new_aggregate := outcome.aggregate.update;
                total_dissent += outcome.position.dissent * amount_left;
                position_consent := outcome.position.consent;
            };

            let new = {
                args with
                pool_id;
                choice;
                timestamp;
                decay;
                dissent = total_dissent / Float.fromInt(amount);
                var consent = position_consent;
                var foresight : Foresight = { reward = 0; apr = { current = 0.0; potential = 0.0; }; };
                var hotness = 0.0;
                var lock : ?LockInfo = null;
            };
            new_positions.add(new);

            // Update the pool aggregate
            RollingTimeline.insert(pool.aggregate, timestamp, new_aggregate);

            // Update the position consents because of the new aggregate
            for (position in pool_positions(pool)) {
                position.consent := position_aggregator.get_consent({ aggregate = new_aggregate; choice = position.choice; time; });
            };

            // Add all new positions to the pool
            add_positions(pool, new_positions.vals(), time);

            { new; previous = Iter.toArray(pool_positions(pool)); };
        };

        public func put_limit_order(pool: Pool<A, C>, args: PutLimitOrderArgs<C>) {

            // TODO: should we check for existing order_id?

            let { order_id; choice; limit_consensus; timestamp; } = args;

            // @order: should change sign based on choice
            // @order: should be checked beforehand ?
            // @order: ideally should directly put a position if limit_consensus is above current consensus
            //let consensus = compute_consensus(pool.aggregate.current.data);
            //if (limit_consensus < consensus){
                //Debug.trap("Limit consensus " # Float.toText(limit_consensus) # " is below current consensus " # Float.toText(consensus));
            //};

            let descending_orders = get_descending_orders(pool, choice);

            // Insert the order in the descending orders btree
            let key = { limit_consensus; timestamp };
            ignore BTree.insert(descending_orders, compare_keys, key, order_id);

            add_order(order_id, {
                order_id;
                pool_id = pool.pool_id;
                timestamp;
                account = args.account;
                choice;
                limit_consensus;
                var amount = Float.fromInt(args.amount);
            });
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
                    tx_id = position.tx_id;
                    supply_index = position.supply_index;
                    from = position.from;
                    decay = position.decay;
                    var consent = position.consent;
                    var foresight = position.foresight;
                    var hotness = position.hotness;
                    var lock = position.lock;
                };
            };
            IterUtils.map(Set.keys(pool.positions), copy_position);
        };

        func get_descending_orders(pool: Pool<A, C>, choice: C) : BTree<LimitOrderBTreeKey, UUID> {
            switch(Map.get(pool.descending_orders, choice_hash, choice)){
                case(null) {
                    let btree = BTree.init<LimitOrderBTreeKey, UUID>(?BTREE_ORDER);
                    Map.set(pool.descending_orders, choice_hash, choice, btree);
                    btree;
                };
                case(?(btree)) { btree; };
            };
        };

        func compare_keys(a: LimitOrderBTreeKey, b: LimitOrderBTreeKey) : Order {
            // First compare by limit_consensus descending
            switch(Float.compare(b.limit_consensus, a.limit_consensus)){
                case(#less) { #less; }; // @order: should depend on choice
                case(#greater) { #greater; }; // @order: should depend on choice
                case(#equal) {
                    // Then compare by timestamp ascending
                    Int.compare(a.timestamp, b.timestamp);
                };
            };
        };

        func add_positions(pool: Pool<A, C>, positions: Iter.Iter<Position<C>>, time: Nat) {
            for (position in positions) {
                // Update the hotness of the previous positions
                lock_info_updater.add(position, pool_positions(pool), time);

                // Add the position to the pool
                add_position(position.position_id, position);
                Set.add(pool.positions, Set.thash, position.position_id);

                // Update TVL by adding the position amount
                pool.tvl += position.amount;
            };
        };

    };

};
