import Result "mo:base/Result";
import Int "mo:base/Int";

module {

    type Result<Ok, Err> = Result.Result<Ok, Err>;

    public type Collateral = {
        amount: Nat;
    };

    public func is_valid(collateral: Collateral) : Bool {
        collateral.amount > 0;
    };

    public func sum(augend: Collateral, addend: Collateral) : Collateral {
        { amount = augend.amount + addend.amount; }
    };

    public func sub(minuend: Collateral, subtrahend: Collateral) : Result<Collateral, Text> {

        if (not is_valid(minuend)) {
            return #err("Collateral.sub error: Invalid minuend");
        };

        if (not is_valid(subtrahend)) {
            return #err("Collateral.sub error: Invalid subtrahend");
        };

        let diff : Int = minuend.amount - subtrahend.amount;

        if (diff < 0) {
            return #err("Subtraction resulted in negative collateral");
        };

        #ok({ amount = Int.abs(diff); });
    };

};