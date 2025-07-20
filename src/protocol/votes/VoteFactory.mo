import VoteController     "VoteController";
import Incentives         "Incentives";
import BallotAggregator   "BallotAggregator";
import Types              "../Types";
import Decay              "../duration/Decay";
import LockInfoUpdater    "../locks/LockInfoUpdater";

import Map                "mo:map/Map";

import Float              "mo:base/Float";
import Iter               "mo:base/Iter";
import Debug "mo:base/Debug";

module {

    type VoteController<A, B> = VoteController.VoteController<A, B>;
    type YesNoAggregate       = Types.YesNoAggregate;
    type YesNoBallot          = Types.YesNoBallot;
    type YesNoChoice          = Types.YesNoChoice;
    type Duration             = Types.Duration;
    type UUID                 = Types.UUID;
    type BallotRegister       = Types.BallotRegister;
    type Parameters   = Types.Parameters;
    
    type Iter<T>              = Iter.Iter<T>;

    public func build_yes_no({
        parameters: Parameters;
        ballot_register: BallotRegister;
        decay_model: Decay.DecayModel;
        lock_info_updater: LockInfoUpdater.LockInfoUpdater;
    }) : VoteController<YesNoAggregate, YesNoChoice> {

        let ballot_aggregator = BallotAggregator.BallotAggregator<YesNoAggregate, YesNoChoice>({
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
                    initial_addend = Float.fromInt(parameters.minimum_ballot_amount);
                    steepness = parameters.dissent_steepness;
                    choice;
                    amount = Float.fromInt(amount);
                    total_yes = decay_model.unwrap_decayed(aggregate.current_yes, time);
                    total_no = decay_model.unwrap_decayed(aggregate.current_no, time);
                });
            };
            compute_consent = func ({aggregate: YesNoAggregate; choice: YesNoChoice; time: Nat;}) : Float {
                Incentives.compute_consent({ 
                    steepness = parameters.consent_steepness;
                    choice;
                    total_yes = decay_model.unwrap_decayed(aggregate.current_yes, time);
                    total_no = decay_model.unwrap_decayed(aggregate.current_no, time);
                });
            };
        });
        
        VoteController.VoteController<YesNoAggregate, YesNoChoice>({
            empty_aggregate = { total_yes = 0; total_no = 0; current_yes = #DECAYED(0.0); current_no = #DECAYED(0.0); };
            ballot_aggregator;
            lock_info_updater;
            decay_model;
            get_ballot = func(id: UUID) : YesNoBallot {
                switch(Map.get(ballot_register.ballots, Map.thash, id)){
                    case(null) { Debug.trap("Ballot not found"); };
                    case(?(#YES_NO(b))) { b; };
                };
            };
            add_ballot = func(id: UUID, ballot: YesNoBallot) {
                Map.set(ballot_register.ballots, Map.thash, id, #YES_NO(ballot));
            };
        });
    };

};