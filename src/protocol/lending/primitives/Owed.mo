import Index "Index";
import LendingTypes "../Types";

import Result "mo:base/Result";

module {

    type Result<Ok, Err> = Result.Result<Ok, Err>;

    type Index = LendingTypes.Index;
    type Owed = LendingTypes.Owed;

    public func is_valid(owed: Owed) : Bool {
        Index.is_valid(owed.index) and owed.accrued_amount >= 0.0 and owed.from_interests >= 0.0;
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
    
};