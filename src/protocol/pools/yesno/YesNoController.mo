import PoolController     "../PoolController";
import YesNoAggregator    "YesNoAggregator";
import Types              "../../Types";
import UUID               "../../utils/Uuid";
import Interfaces         "../../Interfaces";

import Iter               "mo:base/Iter";

module {

    type YesNoAggregate       = Types.YesNoAggregate;
    type YesNoChoice          = Types.YesNoChoice;
    type YesNoLimitOrder      = Types.LimitOrder<YesNoChoice>;
    type PoolController<A, C> = PoolController.PoolController<A, C>;
    type YesNoPosition        = Types.YesNoPosition;
    type Duration             = Types.Duration;
    type UUID                 = Types.UUID;
    type PositionMap     = Types.PositionMap;
    type LimitOrderMap   = Types.LimitOrderMap;
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

    public func build({
        parameters: Parameters;
        decay_model: IDecayModel;
        lock_info_updater: ILockInfoUpdater;
        uuid: UUID.UUIDv7;
        get_position: UUID -> YesNoPosition;
        add_position: (UUID, YesNoPosition) -> ();
        get_order: UUID -> YesNoLimitOrder;
        set_order: (UUID, YesNoLimitOrder) -> ();
        delete_order: UUID -> ();
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
            uuid;
            get_position;
            add_position;
            get_order;
            set_order;
            delete_order;
        });
    };

};