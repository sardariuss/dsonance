import Result "mo:base/Result";
import Int "mo:base/Int";

module {

    type Result<Ok, Err> = Result.Result<Ok, Err>;

    public type Collateral = {
        amount: Nat;
    };

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