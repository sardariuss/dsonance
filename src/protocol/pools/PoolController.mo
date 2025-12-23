import PositionAggregator   "PositionAggregator";
import Types              "../Types";
import RollingTimeline    "../utils/RollingTimeline";
import Interfaces         "../Interfaces";
import IterUtils          "../utils/Iter";
import UUID               "../utils/Uuid";

import Set                "mo:map/Set";
import Map                "mo:map/Map";
import BTree              "mo:stableheapbtreemap/BTree";

import Iter               "mo:base/Iter";
import Order              "mo:base/Order";
import Float              "mo:base/Float";
import Int                "mo:base/Int";
import Buffer             "mo:base/Buffer";
import Debug              "mo:base/Debug";

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
    type IDecayModel = Interfaces.IDecayModel;
    type ILockInfoUpdater = Interfaces.ILockInfoUpdater;

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

    public type PutLimitOrderArgs = {
        order_id: UUID;
        from: Account;
        supply_index: Float;
        timestamp: Nat;
        limit_consensus: Float;
        amount: Nat;
    };
   
    public class PoolController<A, C>({
        empty_aggregate: A;
        choice_hash: Map.HashUtils<C>;
        position_aggregator: PositionAggregator.PositionAggregator<A, C>;
        decay_model: IDecayModel;
        lock_info_updater: ILockInfoUpdater;
        uuid: UUID.UUIDv7;
        // TODO: would be clever to have a generic map interface for positions and orders
        get_position: UUID -> Position<C>;
        add_position: (UUID, Position<C>) -> ();
        get_order: UUID -> LimitOrder<C>;
        add_order: (UUID, LimitOrder<C>) -> ();
        delete_order: UUID -> ();
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

            // @order: fix code smell
            let new = switch(put_position_inner(pool, choice, args, null).position){
                case(null) {
                    Debug.trap("No position created in put_position");
                };
                case(?p) { p; };
            };

            { new; previous = Iter.toArray(pool_positions(pool)); };
        };

        public func put_limit_order(pool: Pool<A, C>, args: PutLimitOrderArgs, choice: C) : { matching: ?{ new: Position<C>; previous: [Position<C>] }; order: ?LimitOrder<C> } {

            let { order_id; limit_consensus; timestamp; from; } = args;
            let position_id = uuid.new();
            let tx_id = 0; // TODO: remove tx_id from position type

            let { position; remaining; } = put_position_inner(pool, choice, { args with from; position_id; tx_id }, ?limit_consensus);

            // @order : fix
            if (remaining == 0.0) {
                // The position fully consumed the limit order
                return { matching = position; };
            };

            let descending_orders = get_descending_orders(pool, choice);

            // Insert the order in the descending orders btree
            let key = { limit_consensus; timestamp };
            ignore BTree.insert(descending_orders, compare_keys, key, order_id);

            add_order(order_id, {
                order_id;
                pool_id = pool.pool_id;
                timestamp;
                from;
                choice;
                limit_consensus;
                var amount = remaining;
            });

            { matching = position };
        };

        public func unlock_position(pool: Pool<A, C>, position_id: UUID) {
            // Just update the TVL
            let position = get_position(position_id);
            pool.tvl -= position.amount;
        };

        public func pool_positions(pool: Pool<A, C>) : Iter<Position<C>> {
            IterUtils.map(Set.keys(pool.positions), get_position);
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

        func put_position_inner(
            pool: Pool<A, C>,
            choice: C,
            args: PutPositionArgs,
            limit_consensus: ?Float
        ) : {
            position: ?Position<C>;
            remaining: Float;
        } {
            let { amount; timestamp; supply_index; } = args;
            let time = timestamp;
            let decay = decay_model.compute_decay(timestamp);

            let new_positions = Buffer.Buffer<Position<C>>(0);
            let push = {
                var amount_left = Float.fromInt(amount);
                var total_dissent = 0.0;
                var position_consent = 0.0;
                var aggregate = pool.aggregate.current.data;
            };

            let opposite_orders = get_descending_orders(pool, position_aggregator.get_opposite_choice(choice));

            label iter_orders for((key, order_id) in BTree.entries(opposite_orders)) {

                // Abort if we have reached the limit consensus
                if(is_target_reached(push.aggregate, choice, limit_consensus)) {
                    break iter_orders;
                };

                let order = get_order(order_id);
                
                // Push the consensus up to that limit order
                push_consensus(push, choice, ?order.limit_consensus, time);
                
                if (push.amount_left <= 0.0) {
                    break iter_orders;
                };

                // Consume the order
                let opposite_position = consume_order(push, order, time, decay, pool, supply_index);
                new_positions.add(opposite_position);

                if (push.amount_left <= 0.0) {
                    break iter_orders;
                };
            };

            // If there is still some amount left and limit is not yet reached, push the rest
            if (not is_target_reached(push.aggregate, choice, limit_consensus) and push.amount_left > 0.0) {
                push_consensus(push, choice, limit_consensus, time);
            };

            if (push.amount_left == Float.fromInt(amount)) {
                // No position was created
                return { position = null; remaining = push.amount_left; };
            };

            // Create the new position
            let position = {
                args with
                pool_id = pool.pool_id;
                choice;
                timestamp;
                decay;
                dissent = push.total_dissent / Float.fromInt(amount);
                var consent = push.position_consent;
                var foresight : Foresight = { reward = 0; apr = { current = 0.0; potential = 0.0; }; };
                var hotness = 0.0;
                var lock : ?LockInfo = null;
            };
            new_positions.add(position);

            // Update the pool aggregate
            RollingTimeline.insert(pool.aggregate, timestamp, push.aggregate);

            // Update the position consents because of the new aggregate
            for (position in pool_positions(pool)) {
                position.consent := position_aggregator.get_consent({ aggregate = push.aggregate; choice = position.choice; time; });
            };

            // Add all new positions to the pool
            add_positions(pool, new_positions.vals(), time);

            {
                position = ?position;
                remaining = Float.fromInt(amount) - push.amount_left;
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

        type PushConsensusInput<A, C> = {
            var aggregate: A;
            var amount_left: Float;
            var total_dissent: Float;
            var position_consent: Float;
        };

        func push_consensus(input: PushConsensusInput<A, C>, choice: C, target_consensus: ?Float, time: Nat) {

            let push_amount = switch(target_consensus){
                case(null){
                    input.amount_left;
                };
                case(?tc){
                    let resistance = position_aggregator.get_resistance({ aggregate = input.aggregate; choice; target_consensus = tc; time; });
                    Float.min(input.amount_left, resistance);
                };
            };  

            // Update the aggregate and total dissent
            // @order: do not cast to Int here, should be done in Float
            let position_outcome = position_aggregator.compute_outcome({ aggregate = input.aggregate; choice; amount = Int.abs(Float.toInt(push_amount)); time; });

            input.aggregate := position_outcome.aggregate.update;
            input.amount_left -= push_amount;
            input.total_dissent += position_outcome.position.dissent * push_amount;
            input.position_consent := position_outcome.position.consent;
        };

        func consume_order(input: PushConsensusInput<A, C>, order: LimitOrder<C>, time: Nat, decay: Float, pool: Pool<A, C>, supply_index: Float) : Position<C> {

            if (input.amount_left <= 0.0) {
                Debug.trap("No amount left to consume the order");
            };

            // With choice = NO, limit_consensus = 0.9, order.amount = 100
            //  -> Worth = (0.9 / 0.1) * 100 = 900.0
            // With choice = NO, limit_consensus = 0.9, order.amount = 30
            //  -> Worth = (0.9 / 0.1) * 30 = 270.0
            let opposite_worth = position_aggregator.get_opposite_worth({ aggregate = input.aggregate; choice = order.choice; amount = order.amount; time; });
            // With amount_left = 500, opposite_worth = 900.0
            //  -> consume_worth = min(500, 900) = 500
            // With amount_left = 500, opposite_worth = 270.0
            //  -> consume_worth = min(500, 270) = 270
            let consume_worth = Float.min(input.amount_left, opposite_worth);
            input.amount_left -= consume_worth;

            let { dissent; consent; } = position_aggregator.compute_outcome({ aggregate = input.aggregate; choice = order.choice; amount = 0; time; }).position;
            input.total_dissent += dissent * consume_worth;
            // Consent stays the same for limit orders

            // With consume_worth = 500, opposite_worth = 900.0
            //  -> order.amount = 100 - (500 / 900) * 100 = 44.44
            // With consume_worth = 270, opposite_worth = 270.0
            //  -> order.amount = 30 - (270 / 270) * 30 = 0.0
            let consumed = consume_worth / opposite_worth * order.amount;
            order.amount -= consumed;
            
            if (consumed >= order.amount) {
                // The position covered the full order
                let descending_orders = get_descending_orders(pool, order.choice);
                let key = { limit_consensus = order.limit_consensus; timestamp = order.timestamp };
                ignore BTree.delete(descending_orders, compare_keys, key);
                delete_order(order.order_id);
            };

            {
                position_id = uuid.new();
                pool_id = pool.pool_id;
                timestamp = time;
                choice = order.choice;
                amount = Int.abs(Float.toInt(consumed));
                dissent;
                tx_id = 0; // @order
                supply_index;
                from = order.from;
                decay;
                var consent = consent;
                var foresight : Foresight = { reward = 0; apr = { current = 0.0; potential = 0.0; }; };
                var hotness = 0.0;
                var lock : ?LockInfo = null;
            };
        };

        func is_target_reached(aggregate: A, direction: C, target: ?Float) : Bool {
            let sign = Float.fromInt(position_aggregator.consensus_direction(direction));

            // If limited up to a certain consensus, check if we have reached it
            switch(target){
                case(null) { false; };
                case(?t){ 
                    let consensus = position_aggregator.get_consensus({ aggregate; });
                    sign * t < sign * consensus; 
                };
            };
        };

    };

};
