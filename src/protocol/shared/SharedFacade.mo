import Types             "../Types";
import Controller        "../Controller";
import Queries           "../Queries";
import SharedConversions "SharedConversions";
import LendingTypes      "../lending/Types";

import Result            "mo:base/Result";

module {

    type Time = Int;
    type UUID = Types.UUID;
    type VoteType = Types.VoteType;
    type BallotType = Types.BallotType;
    type PutBallotResult = Types.PutBallotResult;
    type NewVoteArgs = Types.NewVoteArgs;
    type PutBallotArgs = Types.PutBallotArgs;
    type GetBallotArgs = Types.GetBallotArgs;
    type Account = Types.Account;
    type SBallotType = Types.SBallotType;
    type Duration = Types.Duration;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type SNewVoteResult = Types.SNewVoteResult;
    type NewVoteError = Types.NewVoteError;
    type STimeline<T> = Types.STimeline<T>;
    type ProtocolParameters = Types.ProtocolParameters;
    type SProtocolParameters = Types.SProtocolParameters;
    type SVoteType = Types.SVoteType;
    type SDebtInfo = Types.SDebtInfo;
    type DebtRecord = Types.DebtRecord;
    type PutBallotSuccess = Types.PutBallotSuccess;
    type SPutBallotSuccess = Types.SPutBallotSuccess;
    type SYieldState = Types.SYieldState;
    type UserSupply = Types.UserSupply;
    type LoanPosition = LendingTypes.LoanPosition;
    type Loan = LendingTypes.Loan;
    type BorrowOperation = LendingTypes.BorrowOperation;
    type OperationKind = LendingTypes.OperationKind;
    type TransferResult = Types.TransferResult;
    type ProtocolInfo = Types.ProtocolInfo;

    public class SharedFacade({
        controller: Controller.Controller;
        queries: Queries.Queries;
    }) {

        public func new_vote(args: NewVoteArgs and { origin: Principal; }) : async* SNewVoteResult {
            await* controller.new_vote(args);
        };

        public func put_ballot_for_free(args: PutBallotArgs and { caller: Principal; }) : PutBallotResult {
            controller.put_ballot_for_free(args);
        };

        public func put_ballot(args: PutBallotArgs and { caller: Principal; }) : async* PutBallotResult {
            await* controller.put_ballot(args);
        };

        public func run() : async* Result<(), Text> {
            await* controller.run();
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
        
        public func get_parameters() : SProtocolParameters {
            SharedConversions.shareProtocolParameters(queries.get_parameters());
        };

        public func get_vote_ballots(vote_id: UUID) : [SBallotType] {
            queries.get_vote_ballots(vote_id);
        };

        public func get_votes({origin: Principal; previous: ?UUID; limit: Nat }) : [SVoteType] {
            queries.get_votes({origin; previous; limit; });
        };
        
        public func get_votes_by_author({ author: Account; previous: ?UUID; limit: Nat; }) : [SVoteType] {
            queries.get_votes_by_author({author; previous; limit;});
        };
        
        public func find_vote({vote_id: UUID;}) : ?SVoteType {
            queries.find_vote(vote_id);
        };
        
        public func get_ballots(args: GetBallotArgs) : [SBallotType] {
            queries.get_ballots(args);
        };
        
        public func get_user_supply({ account: Account; }) : UserSupply {
            queries.get_user_supply({account});
        };
        
        public func find_ballot(ballot_id: UUID) : ?SBallotType {
            queries.find_ballot(ballot_id);
        };

        public func get_lending_index() : Types.LendingIndex {
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

        public func get_supply_balance() : Nat {
            controller.get_supply_balance();
        };

        public func get_available_fees() : Nat {
            controller.get_available_fees();
        };

        public func withdraw_fees({ caller: Principal; to: Account; amount: Nat; }) : async* TransferResult {
            await* controller.withdraw_fees({ caller; to; amount; });
        };  

        // @int: commented out for now, will be implemented later
//        public func get_debt_info(debt_id: UUID) : ?SDebtInfo {
//            queries.get_debt_info(debt_id);
//        };
//        
//        public func get_debt_infos(ids: [UUID]) : [SDebtInfo] {
//            queries.get_debt_infos(ids);
//        };
//
//        public func get_mined_by_author({ author: Account }) : DebtRecord {
//            queries.get_mined_by_author({author});
//        };
        
    };
};
