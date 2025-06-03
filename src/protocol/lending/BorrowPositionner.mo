import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Float "mo:base/Float";
import Nat "mo:base/Nat";
import Result "mo:base/Result";
import Int "mo:base/Int";

import Types "../Types";
import Borrow "./primitives/Borrow";
import Collateral "./primitives/Collateral";
import Index "./primitives/Index";
import Owed "./primitives/Owed";
import LendingTypes "Types";

module {

    type Account = Types.Account;
    type TxIndex = Types.TxIndex;
    type Result<Ok, Err> = Result.Result<Ok, Err>;

    type Index            = LendingTypes.Index;
    type Collateral       = LendingTypes.Collateral;
    type Borrow           = LendingTypes.Borrow;
    type Repayment        = LendingTypes.Repayment;
    type RepaymentInfo    = LendingTypes.RepaymentInfo;
    type BorrowPositionTx = LendingTypes.BorrowPositionTx;
    type BorrowPosition   = LendingTypes.BorrowPosition;
    type BorrowParameters = LendingTypes.BorrowParameters;

    public class BorrowPositionner({
        parameters: BorrowParameters;
        collateral_spot_in_asset: () -> Float;
    }){

        if (parameters.max_ltv > parameters.liquidation_threshold){
            Debug.trap("Max LTV exceeds liquidation threshold");
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
            if (not is_healthy({ position = updated_position; index; })) {
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
            if (not is_inferior_max_ltv({ position = update; index; })) {
                return #err("LTV ratio is above current allowed maximum");
            };

            #ok(update);
        };

        public func repay_supply({
            position: BorrowPosition;
            index: Index;
            repayment: Repayment;
        }) : Result<RepaymentInfo, Text> {

            let borrow = switch(position.borrow){
                case(null) { return #err("BorrowPositionner: no borrow to remove"); };
                case(?b) { b; };
            };

            Debug.print("borrow raw amount: " # Float.toText(borrow.raw_amount));

            switch(repayment){
                case(#PARTIAL(amount)) { 
                    let remaining = switch(Borrow.slash(borrow, { accrued_amount = Float.fromInt(amount); index; })){
                        case(#err(err)) { return #err(err); };
                        case(#ok(b)) { b; };
                    };
                    let raw_repaid = switch(remaining){
                        case(null) { borrow.raw_amount; };
                        case(?r) { borrow.raw_amount - r.raw_amount; };
                    };
                    #ok({ amount; remaining; raw_repaid; });
                };
                case(#FULL) { 
                    let due = Owed.accrue_interests(borrow.owed, index).accrued_amount;
                    #ok({
                        amount = Int.abs(Float.toInt(Float.ceil(due)));
                        raw_repaid = borrow.raw_amount;
                        remaining = null; // Borrow is fully repaid
                    });
                };
            };
        };

        public func compute_health_factor({
            position: BorrowPosition;
            index: Index;
        }) : ?Float {
            switch(position.borrow){
                case(null) { return null; }; // No borrow means no risk
                case(?borrow) {
                    let ltv = compute_ltv({ borrow; collateral = position.collateral; index; });
                    if (ltv == 0.0) { return null; }; // No risk if LTV is zero
                    ?(parameters.liquidation_threshold / ltv);
                };
            };
        };

        public func is_healthy({
            position: BorrowPosition;
            index: Index;
        }) : Bool {
            switch(compute_health_factor({ position; index; })){
                case(null) { true; }; // No risk
                case(?h) { h > 1.0; };
            };
        };

        public func compute_ltv({
            borrow: Borrow;
            collateral: Collateral;
            index: Index;
        }) : Float {
            Owed.accrue_interests(borrow.owed, index).accrued_amount 
            / (Float.fromInt(collateral.amount) * collateral_spot_in_asset());
        };

        public func is_inferior_max_ltv({
            position: BorrowPosition;
            index: Index;
        }) : Bool {
            switch(position.borrow){
                case(null) { true; }; // No borrow means no risk
                case(?b) { 
                    compute_ltv({ borrow = b; collateral = position.collateral; index; }) < parameters.max_ltv;
                };
            };
        };

        // https://chatgpt.com/share/683defc1-f6e0-8000-a87e-fc212789a229
        public func to_loan({
            position: BorrowPosition;
            index: Index;
        }) : ?LendingTypes.Loan {

            switch (position.borrow) {
                case (null) { null }; // No active loan, return nothing

                case (?b) {
                    // Protocol parameters for risk and liquidation
                    let { liquidation_threshold; target_ltv; liquidation_penalty; } = parameters;

                    // Compute the up-to-date amount owed, including accrued interest
                    let loan = Borrow.get_current_owed(b, index).accrued_amount;

                    if (loan <= 0.0) {
                        return null; // No loan to report
                    };

                    // Get current spot price of the collateral (in borrow asset units)
                    let price = collateral_spot_in_asset();

                    // Adjust the price downward to simulate the loss from applying the liquidation penalty
                    let effective_price = price * (1.0 - liquidation_penalty);

                    // Convert integer collateral amount to float
                    let collateral = Float.fromInt(position.collateral.amount);

                    // Compute the value of collateral in two ways:
                    // - actual: what it's worth on the open market
                    // - effective: pessimistically discounted for liquidation
                    let collateral_value = {
                        actual = collateral * price;
                        effective = collateral * effective_price;
                    };

                    // Sanity checks to ensure LTV denominator will be valid
                    if (collateral_value.actual <= 0.0 or collateral_value.effective <= 0.0) {
                        Debug.trap("BorrowPositionner: LTV denominator is zero or negative, cannot compute LTV");
                    };

                    // Compute LTVs:
                    // - raw: regular LTV using current spot price
                    // - safe: pessimistic LTV accounting for liquidation losses
                    let ltv = {
                        raw = loan / collateral_value.actual;
                        safe = loan / collateral_value.effective;
                    };

                    if (ltv.raw < 0.0 or ltv.safe < 0.0) {
                        Debug.trap("BorrowPositionner: LTV is negative, this should not happen");
                    };

                    // Compute the max debt that would keep the position within the target LTV
                    let target_loan = collateral * price * target_ltv;

                    // How much repayment is required to bring the position back to target
                    let required_repayment = if (loan > target_loan) {
                        Int.abs(ceil_to_int(loan - target_loan));
                    } else 0;

                    // Health factor: how close the position is to liquidation
                    // < 1.0 means liquidation should happen
                    let health = liquidation_threshold / ltv.safe;

                    // If health is below threshold, compute how much collateral must be liquidated
                    let collateral_to_liquidate = if (health <= 1.0) {
                        let numerator = loan - target_loan;

                        // Denominator accounts for the loss in price due to penalty and the fact
                        // that we want the final LTV to land on target_ltv after liquidation
                        let denominator = price * (1 / (1 + liquidation_penalty) - target_ltv);

                        if (denominator <= 0) {
                            Debug.trap("Invalid liquidation math: denominator <= 0");
                        };

                        ?Int.abs(ceil_to_int(numerator / denominator));
                    } else null;

                    ?{
                        account = position.account;
                        raw_borrowed = b.raw_amount;
                        loan;
                        collateral = position.collateral.amount;
                        ltv = ltv.raw;
                        required_repayment;
                        health;
                        collateral_to_liquidate;
                        liquidation_penalty;
                    };
                };
            };
        };
    };

    func ceil_to_int(x: Float) : Int {
        if (x == Float.floor(x)) { Float.toInt(x) }
        else { Float.toInt(x) + 1 };
    };

    public func add_tx({
        position: BorrowPosition;
        tx: BorrowPositionTx;
    }) : BorrowPosition {
        { position with tx = Array.append(position.tx, [tx]); };
    };

};