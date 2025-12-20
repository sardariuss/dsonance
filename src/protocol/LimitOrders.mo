import SupplyRegistry "lending/SupplyRegistry";

import Types         "Types";
import Map           "mo:map/Map";
import Iter          "mo:base/Iter";
import Float         "mo:base/Float";
import Buffer        "mo:base/Buffer";

import MapUtils      "utils/Map";

module {

    type Account = Types.Account;
    type UUID = Types.UUID;
    type LimitOrderType = Types.LimitOrderType;
    type LimitOrderMap = Types.LimitOrderMap;
    type QueryDirection = Types.QueryDirection;
    type LimitOrder<C> = Types.LimitOrder<C>;

    /// Get all limit orders for a specific account
    public func get_account_orders({ 
        limit_orders: LimitOrderMap;
        account: Account;
        previous: ?UUID;
        limit: Nat;
        direction: QueryDirection; 
    }) : [LimitOrderType] {

        let buffer = Buffer.Buffer<LimitOrderType>(limit);

        let iter = switch(direction) {
            case(#forward) { Map.valsFrom(limit_orders, Map.thash, previous); };
            case(#backward) { Map.valsFromDesc(limit_orders, Map.thash, previous); };
        };

        label limit_loop for (limit_order in iter) {
            if (buffer.size() >= limit) {
                break limit_loop;
            };

            switch(limit_order){
                case(#YES_NO(position)) {
                    // Filter by account
                    if (position.account.owner != account.owner or position.account.subaccount != account.subaccount) {
                        continue limit_loop;
                    };

                    buffer.add(limit_order);
                };
            };
        };

        Buffer.toArray(buffer);
    };

    /// Get the total supply available for an account, considering existing limit orders
    public func get_available_supply(
        limit_orders: LimitOrderMap,
        supply_registry: SupplyRegistry.SupplyRegistry,
        time: Nat,
        account: Account,
    ) : Float {
        let orders_amount = MapUtils.fold_left(limit_orders, 0.0, func(acc: Float, limit_order: LimitOrderType) : Float {
            switch(limit_order) {
                case(#YES_NO(order)) {
                    if (order.account.owner == account.owner and order.account.subaccount == account.subaccount) {
                        acc + order.amount;
                    } else {
                        acc;
                    };
                };
            };
        });

        let supply_info = supply_registry.get_supply_info(time, account);

        supply_info.accrued_amount - orders_amount;
    };

};
