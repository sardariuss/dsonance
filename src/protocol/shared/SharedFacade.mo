import Types             "../Types";
import Controller        "../Controller";
import Queries           "../Queries";
import SharedConversions "SharedConversions";
import LendingTypes      "../lending/Types";

import Result            "mo:base/Result";

module {

    type Time = Int;
    type UUID = Types.UUID;
    type PoolType = Types.PoolType;
    type PositionType = Types.PositionType;
    type PutPositionResult = Types.PutPositionResult;
    type NewPoolArgs = Types.NewPoolArgs;
    type PutPositionArgs = Types.PutPositionArgs;
    type PutPositionPreview = Types.PutPositionPreview;
    type GetPositionArgs = Types.GetPositionArgs;
    type Account = Types.Account;
    type SPositionType = Types.SPositionType;
    type Duration = Types.Duration;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type SNewPoolResult = Types.SNewPoolResult;
    type NewPoolError = Types.NewPoolError;
    type SRollingTimeline<T> = Types.SRollingTimeline<T>;
    type STimeline<T> = Types.STimeline<T>;
    type Parameters = Types.Parameters;
    type SParameters = Types.SParameters;
    type SPoolType = Types.SPoolType;
    type SDebtInfo = Types.SDebtInfo;
    type DebtRecord = Types.DebtRecord;
    type PutPositionSuccess = Types.PutPositionSuccess;
    type SPutPositionSuccess = Types.SPutPositionSuccess;
    type SYieldState = Types.SYieldState;
    type UserSupply = Types.UserSupply;
    type LoanPosition = LendingTypes.LoanPosition;
    type Loan = LendingTypes.Loan;
    type BorrowOperation = LendingTypes.BorrowOperation;
    type OperationKind = LendingTypes.OperationKind;
    type SupplyOperation = LendingTypes.SupplyOperation;
    type SupplyOperationKind = LendingTypes.SupplyOperationKind;
    type SupplyInfo = LendingTypes.SupplyInfo;
    type TransferResult = Types.TransferResult;
    type ProtocolInfo = Types.ProtocolInfo;
    type MiningTracker = Types.MiningTracker;
    type LendingIndex = Types.LendingIndex;
    type QueryDirection = Types.QueryDirection;

    public class SharedFacade({
        controller: Controller.Controller;
        queries: Queries.Queries;
    }) {

        public func new_pool(args: NewPoolArgs and { origin: Principal; }) : async* SNewPoolResult {
            await* controller.new_pool(args);
        };

        public func put_position_for_free(args: PutPositionPreview and { caller: Principal; }) : PutPositionResult {
            controller.put_position_for_free(args);
        };

        public func put_position(args: PutPositionArgs and { caller: Principal; }) : async* PutPositionResult {
            await* controller.put_position(args);
        };

        public func run() : async* () {
            await* controller.run();
        };

        public func claim_mining_rewards(account: Account) : async* ?Nat {
            await* controller.claim_mining_rewards(account);
        };

        public func get_mining_trackers() : [(Account, MiningTracker)] {
            controller.get_mining_trackers();
        };

        public func get_mining_tracker(account: Account) : ?MiningTracker {
            controller.get_mining_tracker(account);
        };

        public func get_mining_total_allocated() : SRollingTimeline<Nat> {
            SharedConversions.shareRollingTimeline(controller.get_mining_total_allocated());
        };

        public func get_mining_total_claimed() : SRollingTimeline<Nat> {
            SharedConversions.shareRollingTimeline(controller.get_mining_total_claimed());
        };

        public func add_clock_offset(duration: Duration) : Result<(), Text> {
            controller.get_clock().add_offset(duration);
        };

        public func set_clock_dilation_factor(dilation_factor: Float) : Result<(), Text> {
            controller.get_clock().set_dilation_factor(dilation_factor);
        };

        public func get_info() : ProtocolInfo {
            controller.get_info();
        };
        
        public func get_parameters() : SParameters {
            SharedConversions.shareParameters(queries.get_parameters());
        };

        public func get_collateral_token_price_usd() : Float {
            controller.get_collateral_token_price_usd();
        };

        public func get_supply_token_price_usd() : Float {
            controller.get_supply_token_price_usd();
        };

        public func get_pool_positions(pool_id: UUID) : [SPositionType] {
            queries.get_pool_positions(pool_id);
        };

        public func get_pools({origin: Principal; previous: ?UUID; limit: Nat; direction: QueryDirection; }) : [SPoolType] {
            queries.get_pools({origin; previous; limit; direction; });
        };

        public func get_pools_by_author({ author: Account; previous: ?UUID; limit: Nat; direction: QueryDirection; }) : [SPoolType] {
            queries.get_pools_by_author({author; previous; limit; direction;});
        };
        
        public func find_pool({pool_id: UUID;}) : ?SPoolType {
            queries.find_pool(pool_id);
        };
        
        public func get_positions(args: GetPositionArgs) : [SPositionType] {
            queries.get_positions(args);
        };
        
        public func get_user_supply({ account: Account; }) : UserSupply {
            queries.get_user_supply({account});
        };
        
        public func find_position(position_id: UUID) : ?SPositionType {
            queries.find_position(position_id);
        };

        public func get_lending_index() : STimeline<LendingIndex> {
            queries.get_lending_index();
        };

        public func run_borrow_operation({
            caller: Principal;
            subaccount: ?Blob;
            amount: Nat;
            kind: OperationKind;
        }) : async* Result<BorrowOperation, Text> {
            await* controller.run_borrow_operation( { account = { owner = caller; subaccount; }; amount; kind; } );
        };

        public func run_borrow_operation_for_free({
            caller: Principal;
            subaccount: ?Blob;
            amount: Nat;
            kind: OperationKind;
        }) : Result<BorrowOperation, Text> {
            controller.run_borrow_operation_for_free( { account = { owner = caller; subaccount; }; amount; kind; } );
        };

        public func get_loan_position(account: Account) : LoanPosition {
            controller.get_loan_position(account);
        };

        public func get_loans_info() : { positions: [Loan]; max_ltv: Float } {
            controller.get_loans_info();
        };

        public func run_supply_operation({
            caller: Principal;
            subaccount: ?Blob;
            amount: Nat;
            kind: SupplyOperationKind;
        }) : async* Result<SupplyOperation, Text> {
            await* controller.run_supply_operation( { account = { owner = caller; subaccount; }; amount; kind; } );
        };

        public func run_supply_operation_for_free({
            caller: Principal;
            subaccount: ?Blob;
            amount: Nat;
            kind: SupplyOperationKind;
        }) : Result<SupplyOperation, Text> {
            controller.run_supply_operation_for_free( { account = { owner = caller; subaccount; }; amount; kind; } );
        };

        public func get_supply_info(account: Account) : SupplyInfo {
            controller.get_supply_info(account);
        };

        public func get_all_supply_info() : { positions: [SupplyInfo]; total_supplied: Float } {
            controller.get_all_supply_info();
        };

        public func get_available_liquidities() : async* Nat {
            await* controller.get_available_liquidities();
        };

        public func get_unclaimed_fees() : Nat {
            controller.get_unclaimed_fees();
        };

        public func withdraw_fees({ caller: Principal; to: Account; amount: Nat; }) : async* TransferResult {
            await* controller.withdraw_fees({ caller; to; amount; });
        };  
        
    };
};
