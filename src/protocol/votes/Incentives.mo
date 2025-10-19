import Types    "../Types";
import Math     "../utils/Math";

import Float  "mo:base/Float";

module {

    type YesNoChoice = Types.YesNoChoice;
    type ForesightParameters = Types.ForesightParameters;

    public func compute_discernment({
        dissent: Float;
        consent: Float;
    }) : Float {
        dissent * consent;
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

}