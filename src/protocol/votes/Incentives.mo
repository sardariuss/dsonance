import Types    "../Types";
import Math     "../utils/Math";

import Float  "mo:base/Float";
import Nat    "mo:base/Nat";

module {

    type YesNoChoice = Types.YesNoChoice;
    type ForesightParameters = Types.ForesightParameters;

    public func compute_discernment({
        dissent: Float;
        consent: Float;
        lock_duration: Nat;
        parameters: ForesightParameters;
    }) : Float {
        dissent * consent * age_bonus(lock_duration, parameters);
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

    func age_bonus(age: Nat, parameters: ForesightParameters) : Float {
        let { max_age; age_coefficient; } = parameters;
        1.0 + age_coefficient * Float.fromInt(Nat.min(age, max_age)) / Float.fromInt(max_age);
    };
}