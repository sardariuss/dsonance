import Types       "Types";
import MapUtils    "utils/Map";
import Clock       "utils/Clock";
import PositionUtils "pools/PositionUtils";
import SharedConversions "shared/SharedConversions";
import LimitOrders "LimitOrders";

import Map         "mo:map/Map";
import Set         "mo:map/Set";

import Option      "mo:base/Option";
import Buffer      "mo:base/Buffer";
import Iter        "mo:base/Iter";
import Debug       "mo:base/Debug";
import Float       "mo:base/Float";
import Array       "mo:base/Array";
import BTree       "mo:stableheapbtreemap/BTree";

module {

    type Time = Nat;
    type PoolRegister = Types.PoolRegister;
    type PoolType = Types.PoolType;
    type PositionType = Types.PositionType;
    type SPositionType = Types.SPositionType;
    type LimitOrderType = Types.LimitOrderType;
    type SPoolType = Types.SPoolType;
    type Account = Types.Account;
    type UUID = Types.UUID;
    type YesNoPool = Types.YesNoPool;
    type PositionMap = Types.PositionMap;
    type DebtRegister = Types.DebtRegister;
    type Iter<T> = Iter.Iter<T>;
    type DebtInfo = Types.DebtInfo;
    type SDebtInfo = Types.SDebtInfo;
    type DebtRecord = Types.DebtRecord;
    type State = Types.State;
    type Parameters = Types.Parameters;
    type UserSupply = Types.UserSupply;
    type STimeline<T> = Types.STimeline<T>;
    type LendingIndex = Types.LendingIndex;
    type QueryDirection = Types.QueryDirection;
    type ChoiceType = Types.ChoiceType;

    public class Queries({
        clock: Clock.Clock;
        state: State;
    }){

        public func get_positions({ account: Account; previous: ?UUID; limit: Nat; filter_active: Bool; direction: QueryDirection; }) : [SPositionType] {
            let buffer = Buffer.Buffer<SPositionType>(limit);

            let iter = switch(direction) {
                case(#forward) { Map.valsFrom(state.positions, Map.thash, previous); };
                case(#backward) { Map.valsFromDesc(state.positions, Map.thash, previous); };
            };

            label limit_loop for (position_type in iter) {
                if (buffer.size() >= limit) {
                    break limit_loop;
                };

                switch(position_type){
                    case(#YES_NO(position)) {
                        // Filter by account
                        if (position.from.owner != account.owner or position.from.subaccount != account.subaccount) {
                            continue limit_loop;
                        };

                        let lock = PositionUtils.unwrap_lock_info(position);
                        if (filter_active and lock.release_date >= clock.get_time()){
                            buffer.add(SharedConversions.sharePositionType(position_type));
                        } else if (not filter_active and lock.release_date < clock.get_time()) {
                            buffer.add(SharedConversions.sharePositionType(position_type));
                        };
                    };
                };
            };

            Buffer.toArray(buffer);
        };

        public func get_limit_orders({ account: Account; previous: ?UUID; limit: Nat; direction: QueryDirection; }) : [LimitOrderType] {
            LimitOrders.get_account_orders({
                limit_orders = state.limit_orders;
                account;
                previous;
                limit;
                direction;
            });
        };

        public func find_position(position_id: UUID) : ?SPositionType {
            Option.map<PositionType, SPositionType>(Map.get(state.positions, Map.thash, position_id), SharedConversions.sharePositionType);
        };

        public func find_pool(pool_id: UUID) : ?SPoolType {
            Option.map<PoolType, SPoolType>(Map.get(state.pool_register.pools, Map.thash, pool_id), SharedConversions.sharePoolType);
        };

        public func get_user_supply({ account: Account; }) : UserSupply {
            let timestamp = clock.get_time();
            var amount = 0;
            var sum_apr = 0.0;

            for (position in Map.vals(state.positions)){
                switch(position){
                    case(#YES_NO(b)) {
                        // Filter by account
                        if (b.from.owner == account.owner and b.from.subaccount == account.subaccount) {
                            let lock = PositionUtils.unwrap_lock_info(b);
                            if (lock.release_date > timestamp){
                                amount += b.amount;
                                sum_apr += (b.foresight.apr.current * Float.fromInt(b.amount));
                            };
                        };
                    };
                };
            };

            if (amount > 0){
                return { amount; apr = sum_apr / Float.fromInt(amount); };
            };

            return { amount = 0; apr = 0.0; };
        };

        public func get_pools({origin: Principal; previous: ?UUID; limit: Nat; direction: QueryDirection;}) : [SPoolType] {
            let buffer = Buffer.Buffer<PoolType>(limit);
            Option.iterate(Map.get(state.pool_register.by_origin, Map.phash, origin), func(ids: Set.Set<UUID>) {
                let iter = Set.keysFrom(ids, Set.thash, previous);
                label limit_loop while (buffer.size() < limit) {
                    let next_id = switch(direction) {
                        case(#forward) { iter.next(); };
                        case(#backward) { iter.prev(); };
                    };
                    switch (next_id) {
                        case (null) { break limit_loop; };
                        case (?id) {
                            Option.iterate(Map.get(state.pool_register.pools, Map.thash, id), func(pool_type: PoolType) {
                                buffer.add(pool_type);
                            });
                        };
                    };
                };
            });
            Buffer.toArray(Buffer.map<PoolType, SPoolType>(buffer, SharedConversions.sharePoolType));
        };

        public func get_pools_by_author({ author: Account; previous: ?UUID; limit: Nat; direction: QueryDirection; }) : [SPoolType] {
            let buffer = Buffer.Buffer<PoolType>(limit);
            Option.iterate(Map.get(state.pool_register.by_author, MapUtils.acchash, author), func(ids: Set.Set<UUID>) {
                let iter = Set.keysFrom(ids, Set.thash, previous);
                label limit_loop while (buffer.size() < limit) {
                    let next_id = switch(direction) {
                        case(#forward) { iter.next(); };
                        case(#backward) { iter.prev(); };
                    };
                    switch (next_id) {
                        case (null) { break limit_loop; };
                        case (?id) {
                            Option.iterate(Map.get(state.pool_register.pools, Map.thash, id), func(pool_type: PoolType) {
                                buffer.add(pool_type);
                            });
                        };
                    };
                };
            });
            Buffer.toArray(Buffer.map<PoolType, SPoolType>(buffer, SharedConversions.sharePoolType));
        };

        public func get_pool_positions(pool_id: UUID) : [SPositionType] {
            let pool = switch(Map.get(state.pool_register.pools, Map.thash, pool_id)){
                case(null) { return []; };
                case(?#YES_NO(v)) { v; };
            };
            let buffer = Buffer.Buffer<SPositionType>(0);
            for (id in Set.keys(pool.positions)){
                switch(Map.get(state.positions, Map.thash, id)){
                    case(null) { Debug.trap("Position not found"); };
                    case(?position) {
                        buffer.add(SharedConversions.sharePositionType(position));
                    };
                };
            };
            Buffer.toArray(buffer);
        };

        public func get_pool_limit_orders(pool_id: UUID) : [(ChoiceType, [LimitOrderType])] {
            let pool = switch(Map.get(state.pool_register.pools, Map.thash, pool_id)){
                case(null) { return []; };
                case(?#YES_NO(v)) { v; };
            };
            
            let result = Buffer.Buffer<(ChoiceType, [LimitOrderType])>(0);

            for ((choice, limit_orders) in Map.entries(pool.descending_orders)){

                let orders_buffer = Buffer.Buffer<LimitOrderType>(0);
                for((_, order_id) in BTree.entries(limit_orders)){
                    orders_buffer.add(MapUtils.getOrTrap(state.limit_orders, Map.thash, order_id));
                };
                result.add((#YES_NO(choice), Buffer.toArray(orders_buffer)));
            };
            Buffer.toArray(result);
        };

        public func get_parameters() : Parameters {
            state.parameters;
        };

        public func get_lending_index() : STimeline<LendingIndex> {
            SharedConversions.shareTimeline(state.lending.index);
        };

    };

};