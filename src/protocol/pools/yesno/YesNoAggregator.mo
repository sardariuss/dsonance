import Incentives         "Incentives";
import PositionAggregator "../PositionAggregator";
import Types              "../../Types";
import Interfaces         "../../Interfaces";
import Decay              "../../duration/Decay";

import Float              "mo:base/Float";

module {

    type A           = Types.YesNoAggregate;
    type C           = Types.YesNoChoice;
    type IDecayModel = Interfaces.IDecayModel;
    type Decayed     = Types.Decayed;
    type Parameters  = {
        minimum_position_amount: Nat;
        foresight: {
            dissent_steepness: Float;
            consent_steepness: Float;
        };
    };

    public func build({
        parameters: Parameters;
        decay_model: IDecayModel;
    }) : PositionAggregator.PositionAggregator<A, C> {

        PositionAggregator.PositionAggregator<A, C>({
            update_aggregate = func({aggregate: A; choice: C; amount: Nat; time: Nat;}) : A {
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
            compute_dissent = func({aggregate: A; choice: C; amount: Nat; time: Nat}) : Float {
                Incentives.compute_dissent({
                    initial_addend = Float.fromInt(parameters.minimum_position_amount);
                    parameters = parameters.foresight;
                    choice;
                    amount = Float.fromInt(amount);
                    total_yes = decay_model.unwrap_decayed(aggregate.current_yes, time);
                    total_no = decay_model.unwrap_decayed(aggregate.current_no, time);
                });
            };
            compute_consent = func ({aggregate: A; choice: C; time: Nat;}) : Float {
                Incentives.compute_consent({ 
                    parameters = parameters.foresight;
                    choice;
                    total_yes = decay_model.unwrap_decayed(aggregate.current_yes, time);
                    total_no = decay_model.unwrap_decayed(aggregate.current_no, time);
                });
            };
            compute_consensus = func(aggregate: A) : Float {
                let #DECAYED(total_yes) = aggregate.current_yes;
                let #DECAYED(total_no) = aggregate.current_no;
                Incentives.compute_consensus({ total_yes; total_no });
            };
            compute_resistance = func(aggregate: A, choice: C, target_consensus: Float, time: Nat) : Float {
                Incentives.compute_resistance({
                    choice;
                    total_yes = decay_model.unwrap_decayed(aggregate.current_yes, time);
                    total_no = decay_model.unwrap_decayed(aggregate.current_no, time);
                    target_consensus = target_consensus;
                });
            };
            compute_decayed_resistance = func(aggregate: A, choice: C, target_consensus: Float) : Decayed {
                Incentives.compute_decayed_resistance({
                    choice;
                    total_yes = aggregate.current_yes;
                    total_no = aggregate.current_no;
                    target_consensus = target_consensus;
                });
            };
            compute_opposite_worth = func(aggregate: A, choice: C, amount: Float, time: Nat) : Float {
                Incentives.compute_opposite_worth({
                    choice;
                    amount;
                    consensus = Incentives.compute_consensus({ 
                        total_yes = decay_model.unwrap_decayed(aggregate.current_yes, time);
                        total_no = decay_model.unwrap_decayed(aggregate.current_no, time);
                    });
                });
            };
            get_opposite_choice = func(choice: C) : C {
                switch(choice){
                    case(#YES) { #NO };
                    case(#NO)  { #YES };
                };
            };
            consensus_direction = func(choice: C) : Int {
                switch(choice){
                    case(#YES) { 1 };
                    case(#NO)  { -1 };
                };
            };
        });
    };

};