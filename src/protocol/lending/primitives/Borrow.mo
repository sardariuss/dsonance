import Index        "Index";
import Owed         "Owed";
import LendingTypes "../Types";

import Result       "mo:base/Result";
import Float        "mo:base/Float";
import Bool         "mo:base/Bool";

module {

    let EPSILON = 0.00001; // TODO: validate this epsilon value

    type Result<Ok, Err> = Result.Result<Ok, Err>;

    type Index = LendingTypes.Index;
    type Owed = LendingTypes.Owed;
    type Borrow = LendingTypes.Borrow;

    public func is_valid(borrow: Borrow) : Bool {
        borrow.raw_amount > 0.0 and Owed.is_valid(borrow.owed);
    };

    public func get_current_owed(borrow: Borrow, index: Index) : Owed {
        Owed.accrue_interests(borrow.owed, index);
    };

    public func new(amount: Nat, index: Index) : Borrow {
        {
            raw_amount = Float.fromInt(amount);
            owed = {
                accrued_amount = Float.fromInt(amount);
                from_interests = 0.0;
                index;
            };
        };
    };

    public func sum(augend: Borrow, addend: Borrow) : Result<Borrow, Text> {

        if (not is_valid(augend)){
            return #err("Borrow.sum error: Invalid augend");
        };

        if (not is_valid(addend)){
            return #err("Borrow.sum error: Invalid addend");
        };

        let owed = switch(Owed.sum(augend.owed, addend.owed)){
            case(#err(err)) { return #err(err); };
            case(#ok(o)) { o; };
        };

        #ok({
            raw_amount = augend.raw_amount + addend.raw_amount;
            owed;
        });
    };

    // Slash a borrow by an owed amount, returning the remaining borrow if any.
    public func slash(borrow: Borrow, amount: Float, index: Index) : Result<?Borrow, Text> {

        if (not is_valid(borrow)) {
            return #err("Borrow.slash error: Invalid borrow");
        };

        if (not Index.less_or_equal(borrow.owed.index, index)) {
            return #err("Borrow.slash error: index of borrow is greater than given index");
        };

        if (amount <= EPSILON) {
            return #err("Borrow.slash error: amount too small");
        };

        let { accrued_amount; from_interests; } = Owed.accrue_interests(borrow.owed, index);

        if (amount > accrued_amount + EPSILON) {
            return #err("Borrow.slash error: amount to slash is greater than owed amount");
        };

        let interests_ratio = from_interests / accrued_amount;

        let new_owed = {
            accrued_amount = accrued_amount - amount;
            from_interests = from_interests - amount * interests_ratio;
            index;
        };

        // Compute the raw amount left after slashing
        let remaining_ratio = new_owed.accrued_amount / accrued_amount;
        let raw_amount = remaining_ratio * borrow.raw_amount;

        if (raw_amount < EPSILON) {
            return #ok(null); // Borrow is fully repaid
        };
        
        #ok(?{
            raw_amount;
            owed = new_owed;
        });
    };
    
};