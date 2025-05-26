import Result "mo:base/Result";
import Int "mo:base/Int";

import LendingTypes "../Types";

module {

    type Result<Ok, Err> = Result.Result<Ok, Err>;

    type Collateral = LendingTypes.Collateral;

    public func sum(augend: Collateral, addend: Collateral) : Collateral {
        { amount = augend.amount + addend.amount; }
    };

    public func sub(minuend: Collateral, subtrahend: Collateral) : Result<Collateral, Text> {

        let diff : Int = minuend.amount - subtrahend.amount;

        if (diff < 0) {
            return #err("Subtraction resulted in negative collateral");
        };

        #ok({ amount = Int.abs(diff); });
    };

};