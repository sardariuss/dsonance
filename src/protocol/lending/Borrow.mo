import Index "Index";
import Owed "Owed";

import Result "mo:base/Result";
import Float "mo:base/Float";
import Bool "mo:base/Bool";

module {

    let EPSILON = 0.00001; // @todo: why not 1.0 ?

    type Index = Index.Index;
    type Result<Ok, Err> = Result.Result<Ok, Err>;

    type Owed = Owed.Owed;

    public type Borrow = {
        // original borrowed, unaffected by index growth
        // used to scale linearly based on repayment proportion
        raw_amount: Float; 
        owed: Owed;
    };

    public func is_valid(borrow: Borrow) : Bool {
        borrow.raw_amount > 0.0 and Owed.is_valid(borrow.owed);
    };

    public func new(amount: Nat, index: Index) : Borrow {
        {
            raw_amount = Float.fromInt(amount);
            owed = Owed.new(amount, index);
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

    public func slash(borrow: Borrow, owed: Owed) : Result<?Borrow, Text> {

        if (not is_valid(borrow)) {
            return #err("Borrow.repay error: Invalid borrow");
        };

        let update_owed = switch(Owed.sub(borrow.owed, owed)){
            case(#err(err)) { return #err(err); };
            case(#ok(o)) { o; };
        };

        if (owed.accrued_amount <= EPSILON) {
            return #err("Borrow.repay error: Repayment owed.accrued_amount too small");
        };

        // Compute the raw amount left after slashing
        let remaining_ratio = update_owed.accrued_amount / owed.accrued_amount;
        let raw_amount = (1 - remaining_ratio) * borrow.raw_amount;

        if (raw_amount < EPSILON) {
            return #ok(null); // Borrow is fully repaid
        };
        
        #ok(?{
            raw_amount;
            owed = update_owed;
        });
    };
    
};