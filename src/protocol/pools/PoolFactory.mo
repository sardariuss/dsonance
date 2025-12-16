import PoolController     "PoolController";
import Incentives         "Incentives";
import PositionAggregator "PositionAggregator";
import Types              "../Types";
import Decay              "../duration/Decay";
import LockInfoUpdater    "../locks/LockInfoUpdater";
import UUID               "../utils/Uuid";

import Map                "mo:map/Map";

import Float              "mo:base/Float";
import Iter               "mo:base/Iter";
import Debug              "mo:base/Debug";

module {

    type PoolController<A, B> = PoolController.PoolController<A, B>;
    type YesNoAggregate       = Types.YesNoAggregate;
    type YesNoPosition        = Types.YesNoPosition;
    type YesNoChoice          = Types.YesNoChoice;
    type Duration             = Types.Duration;
    type UUID                 = Types.UUID;
    type PositionRegister     = Types.PositionRegister;
    type LimitOrder<C>        = Types.LimitOrder<C>;
    type LimitOrderRegister   = Types.LimitOrderRegister;
    type Parameters           = Types.Parameters;
    
    type Iter<T>              = Iter.Iter<T>;

    public func build_yes_no({
        parameters: Parameters;
        position_register: PositionRegister;
        limit_order_register: LimitOrderRegister;
        decay_model: Decay.DecayModel;
        lock_info_updater: LockInfoUpdater.LockInfoUpdater;
    }) : PoolController<YesNoAggregate, YesNoChoice> {

        let position_aggregator = PositionAggregator.PositionAggregator<YesNoAggregate, YesNoChoice>({
            update_aggregate = func({aggregate: YesNoAggregate; choice: YesNoChoice; amount: Nat; time: Nat;}) : YesNoAggregate {
                switch(choice){
                    case(#YES) {{
                        aggregate with 
                        total_yes = aggregate.total_yes + amount;
                        current_yes = Decay.add(aggregate.current_yes, decay_model.create_decayed(Float.fromInt(amount), time)); 
                    }};
                    case(#NO) {{
                        aggregate with 
                        total_no = aggregate.total_no + amount;
                        current_no = Decay.add(aggregate.current_no, decay_model.create_decayed(Float.fromInt(amount), time)); 
                    }};
                };
            };
            compute_dissent = func({aggregate: YesNoAggregate; choice: YesNoChoice; amount: Nat; time: Nat}) : Float {
                Incentives.compute_dissent({
                    initial_addend = Float.fromInt(parameters.minimum_position_amount);
                    parameters = parameters.foresight;
                    choice;
                    amount = Float.fromInt(amount);
                    total_yes = decay_model.unwrap_decayed(aggregate.current_yes, time);
                    total_no = decay_model.unwrap_decayed(aggregate.current_no, time);
                });
            };
            compute_consent = func ({aggregate: YesNoAggregate; choice: YesNoChoice; time: Nat;}) : Float {
                Incentives.compute_consent({ 
                    parameters = parameters.foresight;
                    choice;
                    total_yes = decay_model.unwrap_decayed(aggregate.current_yes, time);
                    total_no = decay_model.unwrap_decayed(aggregate.current_no, time);
                });
            };
            compute_resistance = func(aggregate: YesNoAggregate, choice: YesNoChoice, target_consensus: Float, time: Nat) : Float {
                Incentives.compute_resistance({
                    choice;
                    total_yes = decay_model.unwrap_decayed(aggregate.current_yes, time);
                    total_no = decay_model.unwrap_decayed(aggregate.current_no, time);
                    target_consensus = target_consensus;
                });
            };
            compute_opposite_worth = func(aggregate: YesNoAggregate, choice: YesNoChoice, amount: Float, time: Nat) : Float {
                Incentives.compute_opposite_worth({
                    choice;
                    amount;
                    consensus = Incentives.compute_consensus({ 
                        total_yes = decay_model.unwrap_decayed(aggregate.current_yes, time);
                        total_no = decay_model.unwrap_decayed(aggregate.current_no, time);
                    });
                });
            };
        });

        let uuidv7 = UUID.UUIDv7(UUID.PRNG(0));
        
        PoolController.PoolController<YesNoAggregate, YesNoChoice>({
            empty_aggregate = { total_yes = 0; total_no = 0; current_yes = #DECAYED(0.0); current_no = #DECAYED(0.0); };
            choice_hash = ( 
                func(choice) = switch (choice) {
                    case (#YES) { 0; };
                    case (#NO) { 1; };
                },
                func(a, b) = switch (a, b) {
                    case (#YES, #YES) { true; };
                    case (#NO,  #NO)  { true; };
                    case (_,    _)    { false; };
                }
            );
            position_aggregator;
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
                uuidv7.new();
            };
        });
    };

};