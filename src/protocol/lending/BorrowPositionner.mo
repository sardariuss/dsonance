import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Float "mo:base/Float";
import Nat "mo:base/Nat";
import Result "mo:base/Result";
import Int "mo:base/Int";

import Types "../Types";
import Borrow "Borrow";
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
    type ILiquidityPool   = LendingTypes.ILiquidityPool;

    public class BorrowPositionner({
        liquidity_pool: ILiquidityPool;
        parameters: BorrowParameters;
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
            borrow: Borrow;
            collateral: Collateral;
            index: Index;
        }) : Float {
            parameters.liquidation_threshold / compute_ltv({ borrow; collateral; index; });
        };

        public func is_healthy({
            position: BorrowPosition;
            index: Index;
        }) : Bool {
            switch(position.borrow){
                case(null) { true; }; // No borrow means no risk
                case(?b) { compute_health_factor({ borrow = b; collateral = position.collateral; index; }) > 1.0; };
            };
        };

        public func compute_ltv({
            borrow: Borrow;
            collateral: Collateral;
            index: Index;
        }) : Float {
            Owed.accrue_interests(borrow.owed, index).accrued_amount 
            / (Float.fromInt(collateral.amount) * liquidity_pool.get_collateral_spot_in_asset({ time = index.timestamp; }));
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

    };

    public func add_tx({
        position: BorrowPosition;
        tx: BorrowPositionTx;
    }) : BorrowPosition {
        { position with tx = Array.append(position.tx, [tx]); };
    };

};