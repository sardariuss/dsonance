import Types    "../../Types";
import Math     "../../utils/Math";

import Float  "mo:base/Float";
import Debug  "mo:base/Debug";

module {

    let EPSILON = 1e-6;

    type YesNoChoice = Types.YesNoChoice;
    type Decayed = Types.Decayed;
    type ForesightParameters = Types.ForesightParameters;

    public func compute_consensus({
        total_yes: Float;
        total_no: Float;
    }) : Float {
        let total = total_yes + total_no;
        if (Float.equalWithin(total, 0.0, EPSILON)) {
            0.5;
        } else {
            total_yes / total;
        };
    };

    public func compute_resistance({
        choice: YesNoChoice;
        total_yes: Float;
        total_no: Float;
        target_consensus: Float;
    }) : Float {

        if (Float.equalWithin(target_consensus, 0.0, EPSILON) or
            Float.equalWithin(target_consensus, 1.0, EPSILON)) {
            Debug.trap("Target consensus cannot be 0 or 1");
        };

        let consensus = compute_consensus({ total_yes; total_no; });

        let actual_choice = switch(choice){
            case(#YES) { if (target_consensus >= consensus) { #YES; } else { #NO;  }; };
            case(#NO) {  if (target_consensus <= consensus) { #NO;  } else { #YES; }; };
        };
        
        let sign = switch(choice, actual_choice){
            case(#YES, #YES) {  1.0; };
            case(#NO,  #NO)  {  1.0; };
            case(_  ,    _)  { -1.0; };
        };

        let amount = switch(actual_choice){
            case(#YES) { ( (total_yes + total_no) * target_consensus - total_yes) / (1.0 - target_consensus); };
            case(#NO) {  (-(total_yes + total_no) * target_consensus + total_yes) /        target_consensus;  };
        };

        sign * amount;
    };

    public func compute_decayed_resistance({
        choice: YesNoChoice;
        total_yes: Decayed;
        total_no: Decayed;
        target_consensus: Float;
    }) : Decayed {

        if (Float.equalWithin(target_consensus, 0.0, EPSILON) or
            Float.equalWithin(target_consensus, 1.0, EPSILON)) {
            Debug.trap("Target consensus cannot be 0 or 1");
        };

        let #DECAYED(yes) = total_yes;
        let #DECAYED(no)  = total_no;

        let consensus = compute_consensus({ total_yes = yes; total_no = no; });

        let actual_choice = switch(choice){
            case(#YES) { if (target_consensus >= consensus) { #YES; } else { #NO;  }; };
            case(#NO) {  if (target_consensus <= consensus) { #NO;  } else { #YES; }; };
        };
        
        let sign = switch(choice, actual_choice){
            case(#YES, #YES) {  1.0; };
            case(#NO,  #NO)  {  1.0; };
            case(_  ,    _)  { -1.0; };
        };

        let amount = switch(actual_choice){
            case(#YES) { ( (yes + no) * target_consensus - yes) / (1.0 - target_consensus); };
            case(#NO) {  (-(yes + no) * target_consensus + yes) /        target_consensus;  };
        };

        #DECAYED(sign * amount);
    };

    public func compute_opposite_worth({
        choice: YesNoChoice;
        amount: Float;
        consensus: Float;
    }) : Float {

        if (Float.equalWithin(consensus, 0.0, EPSILON) or
            Float.equalWithin(consensus, 1.0, EPSILON)) {
            Debug.trap("Target consensus cannot be 0 or 1");
        };

        switch(choice){
            case(#YES) {
                amount * (1.0 - consensus) / consensus;
            };
            case(#NO) {
                amount * consensus / (1.0 - consensus);
            };
        };
    };
    
    public func compute_consent({
        parameters: ForesightParameters;
        choice: YesNoChoice;
        total_yes: Float;
        total_no: Float;
    }) : Float {
        let { same; opposit; } = switch(choice){
            case(#YES) { { same = total_yes; opposit = total_no;  }; };
            case(#NO)  { { same = total_no;  opposit = total_yes; }; };
        };
        let total = same + opposit;
        Math.logistic_regression({
            x = same;
            mu = total * 0.5;
            sigma = total * parameters.consent_steepness;
        });
    };

    public func compute_dissent({
        parameters: ForesightParameters;
        initial_addend: Float;
        choice: YesNoChoice;
        amount: Float;
        total_yes: Float; 
        total_no: Float;
    }) : Float {

        let { same; opposit; } = switch(choice){
            case(#YES) { { same = total_yes; opposit = total_no; }; };
            case(#NO) { { same = total_no; opposit = total_yes; }; };
        };

        let steepness = parameters.dissent_steepness;
        let a = opposit + same;
        let b = a + amount;
        let c = opposit + initial_addend;

        var dissent = Float.min(b, c) - Float.min(a, c);
        if (Float.equalWithin(steepness, 1.0, 1e-3)) {
            dissent += c * Float.log(Float.max(b, c) / Float.max(a, c));
        } else {
            dissent += (c ** steepness) / (1 - steepness) * 
                       (Float.max(b, c) ** (1 - steepness) - Float.max(a, c) ** (1 - steepness));
        };

        dissent / amount;
    };

    // TODO: not used anywhere, remove?
    public func compute_amount({
        target_dissent: Float;
        parameters: ForesightParameters;
        choice: YesNoChoice;
        total_yes: Float;
        total_no: Float;
        initial_addend: Float;
    }) : Float {
        
        let { same; opposit; } = switch(choice){
            case(#YES) { { same = total_yes; opposit = total_no; }; };
            case(#NO) { { same = total_no; opposit = total_yes; }; };
        };

        let steepness = parameters.dissent_steepness;
        let total = same + opposit;

        (opposit + initial_addend) / Float.pow(target_dissent, 1.0 / steepness) - total;
    };

}