import Index "Index";
import LendingTypes "../Types";

import Result "mo:base/Result";
import Float "mo:base/Float";

module {

    type Result<Ok, Err> = Result.Result<Ok, Err>;

    type Index = LendingTypes.Index;
    type Owed = LendingTypes.Owed;

    public func is_valid(owed: Owed) : Bool {
        owed.accrued_amount >= 0.0 and Index.is_valid(owed.index) and owed.from_interests >= 0.0;
    };

    public func new(amount: Float, index: Index) : Owed {
        {
            index;
            accrued_amount = amount;
            from_interests = 0.0;
        };
    };

    public func accrue_interests(owed: Owed, index: Index) : Owed {
        {
            index;
            accrued_amount = owed.accrued_amount * index.value / owed.index.value;
            from_interests = owed.accrued_amount * (index.value / owed.index.value - 1.0);
        };
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
            from_interests = owed.from_interests + addend.from_interests;
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

        let interests_diff = owed.from_interests - subtrahend.from_interests;
        if (interests_diff < 0) {
            return #err("Owed sub error: Subtraction resulted in negative owed from_interests");
        };

        #ok({
            owed with
            accrued_amount = accrued_diff;
            from_interests = interests_diff;
        });
    };
    
};