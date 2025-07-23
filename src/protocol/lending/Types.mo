import Error "mo:base/Error";
import Map   "mo:map/Map";
import Set   "mo:map/Set";

// @todo: Find a way to import the types from the protocol to avoid copy pasting
module {

   // ------------------------------ From ICRC1 ------------------------------

    public type Account = {
        owner : Principal;
        subaccount : ?Subaccount;
    };

    public type Subaccount = Blob;

    public type SupportedStandard = {
        name : Text;
        url : Text;
    };

    public type Value = { #Nat : Nat; #Int : Int; #Blob : Blob; #Text : Text; #Array : [Value]; #Map: [(Text, Value)] };

    public type Balance = Nat;

    public type Timestamp = Nat64;

    public type TimeError = {
        #TooOld;
        #CreatedInFuture : { ledger_time : Timestamp };
    };

    public type TxIndex = Nat;

    public type Icrc1TransferError = TimeError or {
        #BadFee : { expected_fee : Balance };
        #BadBurn : { min_burn_amount : Balance };
        #InsufficientFunds : { balance : Balance };
        #Duplicate : { duplicate_of : TxIndex };
        #TemporarilyUnavailable;
        #GenericError : { error_code : Nat; message : Text };
    };
    
    public type Icrc1TransferResult = {
        #Ok : TxIndex;
        #Err : Icrc1TransferError;
    };

    public type Icrc1TransferArgs = {
        from_subaccount : ?Subaccount;
        to : Account;
        amount : Balance;
        fee : ?Balance;
        memo : ?Blob;

        /// The time at which the transaction was created.
        /// If this is set, the canister will check for duplicate transactions and reject them.
        created_at_time : ?Nat64;
    };

    // ------------------------------ FROM PROTOCOL ------------------------------

    public type Transfer = {
        args: Icrc1TransferArgs;
        result: TransferResult;
    };

    public type TransferResult = {
        #ok: TxIndex;
        #err: Text;
    };

    public type TransferError = Icrc1TransferError or { 
        #Trapped : { error_code: Error.ErrorCode; }
    };

    // ------------------------------ ACTUAL MODULE TYPES ------------------------------

    public type UtilizationParameters = {
        // @todo: remove reserve_liquidity, since accumulated fees can already not be withdrawn?
        // Otherwise it should be taken into account when withdrawing supply!
        reserve_liquidity: Float; // portion of supply reserved (0.0 to 1.0, e.g., 0.1 for 10%), to mitigate illiquidity risk
    };

    public type IndexerParameters = {
        lending_fee_ratio: Float; // portion of the supply interest reserved as a fee for the protocol
    };

    public type SupplyParameters = {
        supply_cap: Nat; // maximum amount of supply that can be provided
    };

    public type BorrowParameters = {
        borrow_cap: Nat; // maximum amount of borrow that can be taken
        target_ltv: Float; // ratio, between 0 and 1, e.g. 0.75
        max_ltv: Float; // ratio, between 0 and 1, e.g. 0.75
        liquidation_threshold: Float; // ratio, between 0 and 1, e.g. 0.85
        liquidation_penalty: Float; // ratio, between 0 and 1, e.g. 0.10
        close_factor: Float; // ratio, between 0 and 1, e.g. 0.50, used
                              // to determine how much of the borrow can be repaid
                              // in a single transaction, e.g. 50% of the borrow
                              // can be repaid in a single transaction
        max_slippage: Float;
    };

    public type TWAPConfig = {
        window_duration_ns: Nat; // Duration of the TWAP window in nanoseconds
        max_observations: Nat; // Maximum number of price observations to store
    };

    public type LendingParameters = IndexerParameters and SupplyParameters and BorrowParameters and UtilizationParameters and {
        interest_rate_curve: [CurvePoint];
    };

    public type SellCollateralQuery = ({
        amount: Nat;
    }) -> async* ();

    public type DebtEntry = { 
        timestamp: Nat;
        amount: Float;
    };

    public type AssetAccounting = {
        var reserve: Float; // amount of asset reserved for unsolved debts
        var unsolved_debts: [DebtEntry]; // debts that are not solved yet
    };

    public type Collateral = {
        amount: Nat;
    };

    public type Owed = {
        index: Index;
        accrued_amount: Float;
    };

    public type Borrow = {
        // original borrowed, unaffected by index growth
        // used to scale linearly based on repayment proportion
        raw_amount: Float; 
        owed: Owed;
    };

    public type OperationKind = {
        #PROVIDE_COLLATERAL;
        #WITHDRAW_COLLATERAL;
        #BORROW_SUPPLY;
        #REPAY_SUPPLY: { max_slippage_amount: Nat; };
    };

    public type BorrowOperationArgs = {
        account: Account;
        amount: Nat;
        kind: OperationKind;
    };

    public type RepaymentInfo = {
        repaid: Nat;
        raw_repaid: Float;
        remaining: ?Borrow;
    };

    public type BorrowPositionTx = {
        #COLLATERAL_PROVIDED: TxIndex;
        #COLLATERAL_WITHDRAWNED: TxIndex;
        #SUPPLY_BORROWED: TxIndex;
        #SUPPLY_REPAID: TxIndex;
    };

    public type BorrowPosition = {
        account: Account;
        collateral: Collateral;
        borrow: ?Borrow;
        tx: [BorrowPositionTx];
    };

    public type BorrowOperation = {
        position: LoanPosition;
        index: LendingIndex;
    };

    public type LoanPosition = {
        account: Account;
        collateral: Nat;
        loan: ?Loan;
    };

    public type Loan = {
        raw_borrowed: Float;
        current_owed: Float;
        ltv: Float; // 0 if no borrow
        health: Float; // infinity if no borrow
        required_repayment: Nat;
        collateral_to_liquidate: ?Nat;
        liquidation_penalty: Float;
    };

    public type Index = {
        timestamp: Nat;
        value: Float;
    };

    public type SupplyInput = {
        id: Text;
        account: Account;
        supplied: Nat;
    };

    public type SupplyPosition = SupplyInput and {
        tx: TxIndex;
    };

    public type Withdrawal = {
        id: Text;
        account: Account;
        supplied: Nat;
        due: Nat;
        var transferred: Nat;
        var transfers: [TransferResult]; // TODO: need to limit the number of transfers
    };

    public type BorrowRegister = {
        borrow_positions: Map.Map<Account, BorrowPosition>;
    };

    public type SupplyRegister = {
        supply_positions: Map.Map<Text, SupplyPosition>;
    };

    public type WithdrawalRegister = {
        withdrawals: Map.Map<Text, Withdrawal>;
        withdraw_queue: Set.Set<Text>;
    };

    public type Utilization = {
        raw_supplied: Float;
        raw_borrowed: Float;
        ratio: Float; // Utilization ratio (0.0 to 1.0)
    };

    public type LendingIndex = {
        utilization: Utilization;
        borrow_rate: Float;
        supply_rate: Float;
        accrued_interests: {
            fees: Float;
            supply: Float;
            borrow: Float;
        };
        borrow_index: Index;
        supply_index: Index;
        timestamp: Nat;
    };

    public type LendingRegister = BorrowRegister and SupplyRegister and WithdrawalRegister;

    // A point on the interest rate curve
    public type CurvePoint = {
        utilization: Float; // Utilization ratio (0.0 to 1.0)
        rate: Float; // Annual Percentage Rate (APR) at this utilization (e.g., 0.05 for 5%)
    };

};