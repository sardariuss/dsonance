import Types             "../Types";
import Controller        "../Controller";
import SharedConversions "SharedConversions";

import Result            "mo:base/Result";

module {

    type Time = Int;
    type UUID = Types.UUID;
    type VoteType = Types.VoteType;
    type BallotType = Types.BallotType;
    type PutBallotResult = Types.PutBallotResult;
    type PreviewBallotResult = Types.PreviewBallotResult;
    type SPreviewBallotResult = Types.SPreviewBallotResult;
    type NewVoteArgs = Types.NewVoteArgs;
    type PutBallotArgs = Types.PutBallotArgs;
    type GetBallotArgs = Types.GetBallotArgs;
    type Account = Types.Account;
    type SBallotType = Types.SBallotType;
    type PreviewBallotError = Types.PreviewBallotError;
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

    public class SharedFacade(controller: Controller.Controller) {

        public func new_vote(args: NewVoteArgs and { origin: Principal; }) : async* SNewVoteResult {
            await* controller.new_vote(args);
        };

        public func preview_ballot(args: PutBallotArgs and { caller: Principal; }) : SPreviewBallotResult {
            Result.mapOk<BallotType, SBallotType, PreviewBallotError>(controller.preview_ballot(args), SharedConversions.shareBallotType);
        };

        public func put_ballot(args: PutBallotArgs and { caller: Principal; }) : async* PutBallotResult {
            await* controller.put_ballot(args);
        };

        public func run() : async* () {
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

        public func get_vote_ballots(vote_id: UUID) : [SBallotType] {
            controller.get_queries().get_vote_ballots(vote_id);
        };

        public func get_votes({origin: Principal; filter_ids: ?[UUID] }) : [SVoteType] {
            controller.get_queries().get_votes({origin; filter_ids;});
        };
        
        public func get_votes_by_author({ author: Account; previous: ?UUID; limit: Nat; }) : [SVoteType] {
            controller.get_queries().get_votes_by_author({author; previous; limit;});
        };
        
        public func find_vote({vote_id: UUID;}) : ?SVoteType {
            controller.get_queries().find_vote(vote_id);
        };
        
        public func get_ballots(args: GetBallotArgs) : [SBallotType] {
            controller.get_queries().get_ballots(args);
        };
        
        public func get_locked_amount({ account: Account; }) : Nat {
            controller.get_queries().get_locked_amount({account});
        };
        
        public func find_ballot(ballot_id: UUID) : ?SBallotType {
            controller.get_queries().find_ballot(ballot_id);
        };

        public func get_debt_info(debt_id: UUID) : ?SDebtInfo {
            controller.get_queries().get_debt_info(debt_id);
        };
        
        public func get_debt_infos(ids: [UUID]) : [SDebtInfo] {
            controller.get_queries().get_debt_infos(ids);
        };
        
    };
};
