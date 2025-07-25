import Array        "mo:base/Array";
import Debug        "mo:base/Debug";
import Float        "mo:base/Float";
import Nat          "mo:base/Nat";
import Result       "mo:base/Result";
import Int          "mo:base/Int";

import Types        "Types";
import LedgerTypes  "../ledger/Types";
import Borrow       "./primitives/Borrow";
import Collateral   "./primitives/Collateral";
import Index        "./primitives/Index";
import Owed         "./primitives/Owed";
import Math         "../utils/Math";

module {

    type Result<Ok, Err> = Result.Result<Ok, Err>;

    type Index            = Types.Index;
    type Collateral       = Types.Collateral;
    type Borrow           = Types.Borrow;
    type RepaymentInfo    = Types.RepaymentInfo;
    type BorrowPositionTx = Types.BorrowPositionTx;
    type BorrowPosition   = Types.BorrowPosition;
    type BorrowParameters = Types.BorrowParameters;
    type Loan             = Types.Loan;
    type LoanPosition     = Types.LoanPosition;
    type Account          = LedgerTypes.Account;
    type IPriceTracker    = LedgerTypes.IPriceTracker;

    public class BorrowPositionner({
        parameters: BorrowParameters;
        collateral_price_tracker: IPriceTracker; //  Price of the collateral in terms of the borrow asset
    }){

        switch(validateBorrowParameters(parameters)){
            case(#err(err)) { Debug.trap(err); };
            case(_) { /* Parameters are valid, continue */ };
        };

        public func provide_collateral({
            position: ?BorrowPosition;
            account: Account;
            amount: Nat;
        }) : BorrowPosition {

            switch(position){
                case(null) {
                    {
                        account;
                        collateral = { amount; };
                        borrow = null;
                        tx = [];
                    };
                };
                case(?previous) {
                    if (previous.account != account) {
                        Debug.trap("BorrowPositionner: position account does not match input account");
                    };
                    { previous with collateral = Collateral.sum(previous.collateral, { amount }); };
                };
            };
        };

        public func withdraw_collateral({
            position: BorrowPosition;
            index: Index;
            amount: Nat;
        }) : Result<BorrowPosition, Text> {

            let collateral = switch(Collateral.sub(position.collateral, { amount; })){
                case(#err(err)) { return #err(err); };
                case(#ok(c)) { c; };
            };

            let updated_position = { position with collateral; };

            // Check the withdrawal does not lower the health factor more than 1.0
            let is_healthy = switch(to_loan_position({ position = updated_position; index; }).loan){
                case(null) { true; }; // No loan means no risk
                case(?loan) { loan.health > 1.0; };
            };
            if (not is_healthy) {
                return #err("BorrowPositionner: withdrawal would lower health factor below 1.0");
            };

            #ok({ position with collateral; });
        };
                
        public func borrow_supply({
            position: BorrowPosition;
            index: Index;
            amount: Nat;
        }) : Result<BorrowPosition, Text> {

            // Create a new borrow object
            let borrow = Borrow.new(amount, index);

            // Add to the previous borrowed amount if any
            let sum_result = switch(position.borrow){
                case(null) { #ok(borrow); };
                case(?b) { Borrow.sum(b, borrow); };
            };
            
            // Update the borrow position
            let update = switch(sum_result){
                case(#err(err)) { return #err(err); };
                case(#ok(b)) { { position with borrow = ?b; }; };
            };

            // Check the borrow does not exceed the maximum LTV
            let ltv = switch(to_loan_position({ position = update; index; }).loan){
                case(null) { return #err("BorrowPositionner: loan is null"); };
                case(?l) { l.ltv; };
            };
            
            if (ltv > parameters.max_ltv) {
                return #err("LTV ratio '" # debug_show(ltv) # "' is above current allowed maximum of '" # Float.toText(parameters.max_ltv) # "'");
            };

            #ok(update);
        };

        public func repay_supply({
            position: BorrowPosition;
            index: Index;
            amount: Nat;
            max_slippage_amount: Nat;
        }) : Result<RepaymentInfo, Text> {

            let borrow = switch(position.borrow){
                case(null) { return #err("BorrowPositionner: no borrow to remove"); };
                case(?b) { b; };
            };

            // Do not take more than what is owed
            let clamp_amount = Float.min(Float.fromInt(amount), Owed.accrue_interests(borrow.owed, index).accrued_amount);
 
            var remaining = switch(Borrow.slash(borrow, { accrued_amount = clamp_amount; index; })){
                case(#err(err)) { return #err(err); };
                case(#ok(b)) { b; };
            };
            var repaid = amount;
            let still_owed = switch(remaining){
                case(null) { 0; };
                case(?r) { Math.ceil_to_int(r.owed.accrued_amount); };
            };
            if (still_owed > 0 and still_owed <= max_slippage_amount){
                repaid := amount + Int.abs(still_owed);
                remaining := null; // All owed is repaid
            };
            let raw_repaid = switch(remaining){
                case(null) { borrow.raw_amount; };
                case(?r) { borrow.raw_amount - r.raw_amount; };
            };
            #ok({ repaid; raw_repaid; remaining; });
        };

        public func to_loan_position({
            position: BorrowPosition;
            index: Index;
        }) : LoanPosition {

            let loan = switch(position.borrow){
                case(null) { null; };
                case(?borrow) { 
                    to_loan({ 
                        collateral_amount = position.collateral.amount;
                        borrow;
                        index;
                    }); 
                };
            };

            {
                account = position.account;
                collateral = position.collateral.amount;
                loan;
            };
        };

        func to_loan({
            collateral_amount: Nat;
            borrow: Borrow;
            index: Index;
        }) : ?Loan {

            // Protocol parameters for risk and liquidation
            let { liquidation_threshold; target_ltv; liquidation_penalty; close_factor; } = parameters;

            // Compute the up-to-date amount owed, including accrued interest
            let current_owed = Borrow.get_current_owed(borrow, index).accrued_amount;

            if (current_owed <= 0.0) {
                return null; // No loan to report
            };

            // Get current spot price of the collateral (in borrow asset units)
            let price = collateral_price_tracker.get_price();

            // Convert integer collateral amount to float
            let collateral = Float.fromInt(collateral_amount);

            // Compute the value of collateral
            let collateral_value = collateral * price;

            // Sanity checks to ensure LTV denominator will be valid
            if (collateral_value <= 0.0) {
                Debug.trap("BorrowPositionner: LTV denominator is zero or negative, cannot compute LTV");
            };

            // Compute LTV
            let ltv = current_owed / collateral_value;

            if (ltv < 0.0) {
                Debug.trap("BorrowPositionner: LTV is negative, this should not happen");
            };

            // Compute the max debt that would keep the position within the target LTV
            let target_owed = collateral * price * target_ltv;

            // How much repayment is required to bring the position back to target
            let required_repayment = if (current_owed <= target_owed) 0 else {
                Int.abs(Math.ceil_to_int(current_owed - target_owed));
            };

            // Health factor: how close the position is to liquidation
            // < 1.0 means liquidation should happen
            let health = liquidation_threshold / ltv;

            // If health is below threshold, compute how much collateral must be liquidated
            let collateral_to_liquidate = if (health > 1.0) null else {
                let numerator = current_owed - target_owed;

                // Exact formula from algebric resolution gives: P * (1 / (1 + penalty) - target_ltv)
                let denominator = price * (1 / (1 + liquidation_penalty) - target_ltv);

                if (denominator <= 0.0) {
                    Debug.trap("BorrowPositionner: Invalid liquidation math: denominator <= 0");
                };

                var liquidation_amount = numerator / denominator;
                liquidation_amount := Float.min(liquidation_amount, collateral * close_factor);

                ?Int.abs(Math.ceil_to_int(liquidation_amount));
            };

            ?{
                raw_borrowed = borrow.raw_amount;
                current_owed;
                ltv;
                required_repayment;
                health;
                collateral_to_liquidate;
                liquidation_penalty;
            };
        };
    };

    func validateBorrowParameters(p: BorrowParameters) : Result.Result<(), Text> {
        if (not Math.is_normalized(p.target_ltv) or p.target_ltv == 0.0) {
            return #err("target_ltv must be > 0 and ≤ 1");
        };

        if (not Math.is_normalized(p.max_ltv) or p.max_ltv == 0.0) {
            return #err("max_ltv must be > 0 and ≤ 1");
        };

        if (not Math.is_normalized(p.liquidation_threshold) or p.liquidation_threshold == 0.0) {
            return #err("liquidation_threshold must be > 0 and ≤ 1");
        };

        if (not Math.is_normalized(p.liquidation_penalty) or p.liquidation_penalty == 0.0 or p.liquidation_penalty > 0.5) {
            return #err("liquidation_penalty must be > 0 and ≤ 0.5");
        };

        if (not Math.is_normalized(p.close_factor) or p.close_factor == 0.0) {
            return #err("close_factor must be > 0 and ≤ 1");
        };

        if (p.max_ltv < p.target_ltv) {
            return #err("max_ltv must be ≥ target_ltv");
        };

        if (p.liquidation_threshold < p.max_ltv) {
            return #err("liquidation_threshold must be ≥ max_ltv");
        };

        if (p.liquidation_penalty > 0.05) {
            Debug.trap("Liquidation penalty too high.");
        };

        let threshold = 1.0 / (1.0 + p.liquidation_penalty);
        if (p.target_ltv >= threshold) {
            return #err("target_ltv must be < 1 / (1 + liquidation_penalty) ≈ " # Float.toText(threshold));
        };

        return #ok;
    };

    public func add_tx({
        position: BorrowPosition;
        tx: BorrowPositionTx;
    }) : BorrowPosition {
        { position with tx = Array.append(position.tx, [tx]); };
    };

};