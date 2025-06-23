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
    type SProtocolInfo = Types.SProtocolInfo;
    type TimerParameters = Types.TimerParameters;
    type STimeline<T> = Types.STimeline<T>;
    type ProtocolParameters = Types.ProtocolParameters;
    type SProtocolParameters = Types.SProtocolParameters;
    type SVoteType = Types.SVoteType;
    type SDebtInfo = Types.SDebtInfo;
    type DebtRecord = Types.DebtRecord;
    type BallotPreview = Types.BallotPreview;
    type SBallotPreview = Types.SBallotPreview;
    type SYieldState = Types.SYieldState;
    type LoanPosition = LendingTypes.LoanPosition;
    type BorrowOperation = LendingTypes.BorrowOperation;

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

        public func set_timer_interval({ caller: Principal; interval_s: Nat; }) : async* Result<(), Text> {
            await* controller.set_timer_interval({ caller; interval_s; });
        };

        public func start_timer({ caller: Principal; }) : async* Result<(), Text> {
            await* controller.start_timer({ caller; });
        };

        public func stop_timer({ caller: Principal }) : Result<(), Text> {
            controller.stop_timer({ caller; });
        };

        public func add_clock_offset(duration: Duration) : Result<(), Text> {
            controller.get_clock().add_offset(duration);
        };

        public func set_clock_dilation_factor(dilation_factor: Float) : Result<(), Text> {
            controller.get_clock().set_dilation_factor(dilation_factor);
        };

        public func get_info() : SProtocolInfo {
            SharedConversions.shareProtocolInfo(controller.get_info());
        };
        
        public func get_parameters() : SProtocolParameters {
            SharedConversions.shareProtocolParameters(controller.get_parameters());
        };

        public func get_lending_parameters() : Types.LendingParameters {
            queries.get_lending_parameters();
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
        
        public func get_locked_amount({ account: Account; }) : Nat {
            queries.get_locked_amount({account});
        };
        
        public func find_ballot(ballot_id: UUID) : ?SBallotType {
            queries.find_ballot(ballot_id);
        };

        public func get_lending_index() : Types.LendingIndex {
            queries.get_lending_index();
        };

        public func supply_collateral({ caller: Principal; subaccount: ?Blob; amount: Nat; }) : async* Result<BorrowOperation, Text> {
            await* controller.supply_collateral({ account = { owner = caller; subaccount; }; amount; });
        };

        public func preview_supply_collateral({ caller: Principal; subaccount: ?Blob; amount: Nat; }) : Result<BorrowOperation, Text> {
           controller.preview_supply_collateral({ account = { owner = caller; subaccount; }; amount; });
        };

        public func withdraw_collateral({ caller: Principal; subaccount: ?Blob; amount: Nat; }) : async* Result<BorrowOperation, Text> {
            await* controller.withdraw_collateral({ account = { owner = caller; subaccount; }; amount; });
        };

        public func borrow({ caller: Principal; subaccount: ?Blob; amount: Nat; }) : async* Result<BorrowOperation, Text> {
            await* controller.borrow({ account = { owner = caller; subaccount; }; amount; });
        };

        public func repay({ caller: Principal; subaccount: ?Blob; repayment: { #PARTIAL: Nat; #FULL; }; }) : async* Result<BorrowOperation, Text> {
            await* controller.repay({ account = { owner = caller; subaccount; }; repayment; });
        };

        public func get_loan_position(account: Account) : LoanPosition {
            controller.get_loan_position(account);
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
