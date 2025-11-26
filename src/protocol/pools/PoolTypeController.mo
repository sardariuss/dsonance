import PoolController "PoolController";
import Types          "../Types";
import IterUtils      "../utils/Iter";

import Iter           "mo:base/Iter";
import Array          "mo:base/Array";
import Map            "mo:map/Map";

module {

    type PoolType          = Types.PoolType;
    type ChoiceType        = Types.ChoiceType;
    type PoolTypeEnum      = Types.PoolTypeEnum;
    type YesNoAggregate    = Types.YesNoAggregate;
    type YesNoChoice       = Types.YesNoChoice;
    type YesNoPosition       = Types.YesNoPosition;
    type UUID              = Types.UUID;
    type PositionType        = Types.PositionType;
    type Account           = Types.Account;
    type PutPositionSuccess  = Types.PutPositionSuccess;
    type Iter<T>           = Map.Iter<T>;

    // TODO: put in Types.mo
    public type PutPositionArgs = PoolController.PutPositionArgs;

    public class PoolTypeController({
        yes_no_controller: PoolController.PoolController<YesNoAggregate, YesNoChoice>;
    }){

        public func new_pool({ pool_id: UUID; tx_id: Nat; pool_type_enum: PoolTypeEnum; date: Nat; origin: Principal; author: Account }) : PoolType {
            switch(pool_type_enum){
                case(#YES_NO) { #YES_NO(yes_no_controller.new_pool({pool_id; tx_id; date; origin; author;})); }
            };
        };

        public func put_position({ pool_type: PoolType; choice_type: ChoiceType; args: PutPositionArgs; }) : { new: PositionType; previous: [PositionType] } {
            switch(pool_type, choice_type){
                case(#YES_NO(pool), #YES_NO(choice)) { 
                    let { new; previous; } = (yes_no_controller.put_position(pool, choice, args));
                    { new = #YES_NO(new); previous = Array.map(previous, func(b: YesNoPosition) : PositionType { #YES_NO(b); }) };
                };
            };
        };

        public func unlock_position({ pool_type: PoolType; position_id: UUID; }) {
            switch(pool_type){
                case(#YES_NO(pool)){
                    yes_no_controller.unlock_position(pool, position_id);      
                };
            };
        };

        public func pool_positions(pool_type: PoolType) : Iter<PositionType> {
            switch(pool_type){
                case(#YES_NO(pool)) { 
                    IterUtils.map(yes_no_controller.pool_positions(pool), func (b: YesNoPosition) : PositionType {
                        #YES_NO(b);
                    });
                };
            };
        };

    };

};