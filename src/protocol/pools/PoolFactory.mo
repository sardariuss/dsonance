import PoolController     "PoolController";
import YesNoAggregator    "yesno/YesNoAggregator";
import Types              "../Types";
import UUID               "../utils/Uuid";
import Interfaces         "../Interfaces";

import Map                "mo:map/Map";

import Iter               "mo:base/Iter";
import Debug              "mo:base/Debug";

module {

    type YesNoAggregate       = Types.YesNoAggregate;
    type YesNoChoice          = Types.YesNoChoice;
    type PoolController<A, C> = PoolController.PoolController<A, C>;
    type YesNoPosition        = Types.YesNoPosition;
    type Duration             = Types.Duration;
    type UUID                 = Types.UUID;
    type PositionRegister     = Types.PositionRegister;
    type LimitOrder<C>        = Types.LimitOrder<C>;
    type LimitOrderRegister   = Types.LimitOrderRegister;
    type Parameters           = Types.Parameters;
    type IDecayModel          = Interfaces.IDecayModel;
    type ILockInfoUpdater     = Interfaces.ILockInfoUpdater;

    type Iter<T>              = Iter.Iter<T>;

    public func build_yes_no({
        parameters: Parameters;
        position_register: PositionRegister;
        limit_order_register: LimitOrderRegister;
        decay_model: IDecayModel;
        lock_info_updater: ILockInfoUpdater;
        uuid: UUID.UUIDv7;
    }) : PoolController<YesNoAggregate, YesNoChoice> {
        
        PoolController.PoolController<YesNoAggregate, YesNoChoice>({
            empty_aggregate = { total_yes = 0; total_no = 0; current_yes = #DECAYED(0.0); current_no = #DECAYED(0.0); };
            choice_hash = ( 
                func(choice) = switch (choice) {
                    case (#YES) { 0; };
                    case (#NO) { 1; };
                },
                func(a, b) = switch (a, b) {
                    case (#YES, #YES) { true;  };
                    case (#NO ,  #NO) { true;  };
                    case (_   ,    _) { false; };
                }
            );
            position_aggregator = YesNoAggregator.build({ parameters; decay_model; });
            lock_info_updater;
            decay_model;
            get_position = func(id: UUID) : YesNoPosition {
                switch(Map.get(position_register.positions, Map.thash, id)){
                    case(null) { Debug.trap("Position not found"); };
                    case(?(#YES_NO(b))) { b; };
                };
            };
            add_position = func(id: UUID, position: YesNoPosition) {
                Map.set(position_register.positions, Map.thash, id, #YES_NO(position));
            };
            get_order = func(id: UUID) : LimitOrder<YesNoChoice> {
                switch(Map.get(limit_order_register.orders, Map.thash, id)){
                    case(null) { Debug.trap("Limit order not found"); };
                    case(?(#YES_NO(order))) { order; };
                };
            };
            add_order = func(id: UUID, order: LimitOrder<YesNoChoice>) {
                Map.set(limit_order_register.orders, Map.thash, id, #YES_NO(order));
            };
            delete_order = func(id: UUID) {
                Map.delete(limit_order_register.orders, Map.thash, id);
            };
            generate_uuid = func() : Text {
                uuid.new();
            };
        });
    };

};