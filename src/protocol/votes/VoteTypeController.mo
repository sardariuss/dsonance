import VoteController "VoteController";
import Types          "../Types";
import IterUtils      "../utils/Iter";

import Iter           "mo:base/Iter";
import Array          "mo:base/Array";
import Map            "mo:map/Map";

module {

    type VoteType       = Types.VoteType;
    type ChoiceType     = Types.ChoiceType;
    type VoteTypeEnum   = Types.VoteTypeEnum;
    type YesNoAggregate = Types.YesNoAggregate;
    type YesNoChoice    = Types.YesNoChoice;
    type YesNoBallot    = Types.YesNoBallot;
    type UUID           = Types.UUID;
    type BallotType     = Types.BallotType;
    type Account        = Types.Account;
    type BallotPreview  = Types.BallotPreview;
    
    type Iter<T>        = Map.Iter<T>;

    // TODO: put in Types.mo
    public type PutBallotArgs = VoteController.PutBallotArgs;

    public class VoteTypeController({
        yes_no_controller: VoteController.VoteController<YesNoAggregate, YesNoChoice>;
    }){

        public func new_vote({ vote_id: UUID; tx_id: Nat; vote_type_enum: VoteTypeEnum; date: Nat; origin: Principal; author: Account }) : VoteType {
            switch(vote_type_enum){
                case(#YES_NO) { #YES_NO(yes_no_controller.new_vote({vote_id; tx_id; date; origin; author;})); }
            };
        };

        public func put_ballot({ vote_type: VoteType; choice_type: ChoiceType; args: PutBallotArgs; }) : BallotType {
            switch(vote_type, choice_type){
                case(#YES_NO(vote), #YES_NO(choice)) { #YES_NO(yes_no_controller.put_ballot(vote, choice, args)); };
            };
        };

        public func vote_ballots(vote_type: VoteType) : Iter<BallotType> {
            switch(vote_type){
                case(#YES_NO(vote)) { 
                    IterUtils.map(yes_no_controller.vote_ballots(vote), func (b: YesNoBallot) : BallotType {
                        #YES_NO(b);
                    });
                };
            };
        };

    };

};