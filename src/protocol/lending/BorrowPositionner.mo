import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Float "mo:base/Float";
import Array "mo:base/Array";
import Result "mo:base/Result";

import Types "../Types";
import Borrow "Borrow";
import Collateral "Collateral";
import Index "Index";
import Owed "Owed";

module {

    type Duration = Types.Duration;
    type Account = Types.Account;
    type TxIndex = Types.TxIndex;
    type Index = Index.Index;
    type Result<Ok, Err> = Result.Result<Ok, Err>;

    type Collateral = Collateral.Collateral;
    type Borrow = Borrow.Borrow;

    public type RepaymentArgs  = {
        #PARTIAL: Nat;
        #FULL;
    };

    public type RepaymentInfo = {
        amount: Nat;
        raw_difference: Float;
        borrow: ?Borrow;
    };

    type Tx = {
        #COLLATERAL_PROVIDED: TxIndex;
        #COLLATERAL_WITHDRAWNED: TxIndex;
        #SUPPLY_BORROWED: TxIndex;
        #SUPPLY_REPAID: TxIndex;
    };

    public type BorrowPosition = {
        account: Account;
        collateral: Collateral;
        borrow: ?Borrow;
        tx: [Tx];
    };

    // @todo: check how to handle position duration when collateral is added
    public class BorrowPositionner({
        get_collateral_spot_in_asset: ({ time: Nat; }) -> Float;
        //max_borrow_duration: Duration; // the maximum duration a borrow position can last before it gets liquidated
        max_ltv: Float; // ratio, between 0 and 1, e.g. 0.75
        liquidation_threshold: Float; // ratio, between 0 and 1, e.g. 0.85
    }){

        if (max_ltv > liquidation_threshold){
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

            var borrow = Borrow.new(amount, index);

            let sum_result = switch(position.borrow){
                case(null) { #ok(borrow); };
                case(?b) { Borrow.sum(b, borrow); };
            };

            borrow := switch(sum_result){
                case(#err(err)) { return #err(err); };
                case(#ok(b)) { b; };
            };

            let update = { position with borrow = ?borrow; };

            // Check the borrow does not exceed the maximum LTV
            if (not is_inferior_max_ltv({ position = update; index; })) {
                return #err("LTV ratio is above current allowed maximum");
            };

            #ok(update);
        };

        public func repay_supply({
            position: BorrowPosition;
            index: Index;
            args: RepaymentArgs;
        }) : Result<RepaymentInfo, Text> {

            let borrow = switch(position.borrow){
                case(null) { return #err("BorrowPositionner: no borrow to remove"); };
                case(?b) { b; };
            };

            let repayment = switch(args){
                case(#PARTIAL(amount)) { 
                    let remaining = switch(Borrow.slash(borrow, Owed.new(amount, index))){
                        case(#err(err)) { return #err(err); };
                        case(#ok(b)) { b; };
                    };
                    {
                        amount;
                        raw_difference = borrow.raw_amount - remaining.raw_amount;
                        borrow = ?remaining; 
                    };
                };
                case(#FULL) {
                    {   
                        amount = Owed.owed_amount(borrow.owed, index);
                        raw_difference = borrow.raw_amount;
                        borrow = null; 
                    };
                };
            };

            #ok(repayment);
        };

        public func compute_health_factor({
            position: BorrowPosition;
            index: Index;
        }) : Float {
            liquidation_threshold / compute_ltv({ position; index; });
        };

        public func is_healthy({
            position: BorrowPosition;
            index: Index;
        }) : Bool {
            compute_health_factor({ position; index; }) > 1.0;
        };

        public func compute_ltv({
            position: BorrowPosition;
            index: Index;
        }) : Float {
            let accrued_amount = switch(position.borrow){
                case(null) { 0.0; }; // @todo: check if no side effect
                case(?b) { Owed.accrue_interests(b.owed, index).accrued_amount; };
            };
            accrued_amount / (Float.fromInt(position.collateral.amount) * get_collateral_spot_in_asset({ time = index.timestamp; }));
        };

        public func is_inferior_max_ltv({
            position: BorrowPosition;
            index: Index;
        }) : Bool {
            compute_ltv({ position; index; }) < max_ltv;
        };

    };

    public func add_tx({
        position: BorrowPosition;
        tx: Tx;
    }) : BorrowPosition {
        { position with tx = Array.append(position.tx, [tx]); };
    };

};