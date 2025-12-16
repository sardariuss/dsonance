import PoolController     "PoolController";
import YesNoController    "yesno/YesNoController";
import Types              "../Types";
import UUID               "../utils/Uuid";
import Interfaces         "../Interfaces";

import Map                "mo:map/Map";

import Iter               "mo:base/Iter";
import Debug              "mo:base/Debug";

module {

    type YesNoAggregate       = Types.YesNoAggregate;
    type YesNoChoice          = Types.YesNoChoice;
    type YesNoLimitOrder      = Types.LimitOrder<YesNoChoice>;
    type PoolController<A, C> = PoolController.PoolController<A, C>;
    type YesNoPosition        = Types.YesNoPosition;
    type Duration             = Types.Duration;
    type UUID                 = Types.UUID;
    type PositionMap     = Types.PositionMap;
    type LimitOrderMap        = Types.LimitOrderMap;
    type IDecayModel          = Interfaces.IDecayModel;
    type ILockInfoUpdater     = Interfaces.ILockInfoUpdater;

    type Parameters = {
        minimum_position_amount: Nat;
        foresight: {
            dissent_steepness: Float;
            consent_steepness: Float;
        };
    };

    type Iter<T>              = Iter.Iter<T>;

    public func build_yes_no({
        parameters: Parameters;
        positions: PositionMap;
        limit_orders: LimitOrderMap;
        decay_model: IDecayModel;
        lock_info_updater: ILockInfoUpdater;
        uuid: UUID.UUIDv7;
    }) : PoolController<YesNoAggregate, YesNoChoice> {
        
        YesNoController.build({
            parameters;
            decay_model;
            lock_info_updater;
            uuid;
            get_position = func(id: UUID) : YesNoPosition {
                switch(Map.get(positions, Map.thash, id)){
                    case(null) { Debug.trap("Position not found"); };
                    case(?(#YES_NO(b))) { b; };
                };
            };
            add_position = func(id: UUID, position: YesNoPosition) {
                Map.set(positions, Map.thash, id, #YES_NO(position));
            };
            get_order = func(id: UUID) : YesNoLimitOrder {
                switch(Map.get(limit_orders, Map.thash, id)){
                    case(null) { Debug.trap("Limit order not found"); };
                    case(?(#YES_NO(order))) { order; };
                };
            };
            add_order = func(id: UUID, order: YesNoLimitOrder) {
                Map.set(limit_orders, Map.thash, id, #YES_NO(order));
            };
            delete_order = func(id: UUID) {
                Map.delete(limit_orders, Map.thash, id);
            };
        });
    };

};