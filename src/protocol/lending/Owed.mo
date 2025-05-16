import Index "Index";
import LendingTypes "Types";

import Result "mo:base/Result";
import Float "mo:base/Float";
import Int "mo:base/Int";

module {

    type Result<Ok, Err> = Result.Result<Ok, Err>;

    type Index = LendingTypes.Index;
    type Owed = LendingTypes.Owed;

    public func is_valid(owed: Owed) : Bool {
        owed.accrued_amount > 0.0 and Index.is_valid(owed.index);
    };

    public func new(amount: Nat, index: Index) : Owed {
        {
            index;
            accrued_amount = Float.fromInt(amount);
        };
    };

    public func accrue_interests(owed: Owed, index: Index) : Owed {
        {
            index;
            accrued_amount = owed.accrued_amount * index.value / owed.index.value;
        };
    };

    public func owed_amount(owed: Owed, index: Index) : Nat {
        Int.abs(Float.toInt(Float.ceil(accrue_interests(owed, index).accrued_amount)));
    };

    public func sum(augend: Owed, addend: Owed) : Result<Owed, Text> {

        if (not is_valid(augend)) {
            return #err("Owed sum error: Invalid augend");
        };

        if (not is_valid(addend)) {
            return #err("Owed sum error: Invalid addend");
        };

        if(not Index.less_or_equal(augend.index, addend.index)) {
            return #err("Owed sum error: Index of augend is greater than index of addend");
        };

        let owed = accrue_interests(augend, addend.index);

        #ok({
            owed with
            accrued_amount = owed.accrued_amount + addend.accrued_amount;
        });
    };

    public func sub(minuend: Owed, subtrahend: Owed) : Result<Owed, Text> {

        if (not is_valid(minuend)) {
            return #err("Owed sub error: Invalid minuend");
        };

        if (not is_valid(subtrahend)) {
            return #err("Owed sub error: Invalid subtrahend");
        };

        if (not Index.less_or_equal(minuend.index, subtrahend.index)) {
            return #err("Owed sub error: index of minuend is greater than index of subtrahend");
        };

        let owed = accrue_interests(minuend, subtrahend.index);
        let accrued_diff = owed.accrued_amount - subtrahend.accrued_amount;

        if (accrued_diff < 0) {
            return #err("Owed sub error: Subtraction resulted in negative owed amount");
        };

        #ok({
            owed with
            accrued_amount = accrued_diff;
        });
    };
    
};