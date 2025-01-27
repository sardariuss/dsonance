import Types             "../Types";
import Controller        "../Controller";
import SharedConversions "SharedConversions";

import Array             "mo:base/Array";
import Option            "mo:base/Option";
import Result            "mo:base/Result";

module {

    type Time = Int;
    type UUID = Types.UUID;
    type VoteType = Types.VoteType;
    type BallotType = Types.BallotType;
    type SVoteType = Types.SVoteType;
    type PutBallotResult = Types.PutBallotResult;
    type PreviewBallotResult = Types.PreviewBallotResult;
    type SPreviewBallotResult = Types.SPreviewBallotResult;
    type NewVoteArgs = Types.NewVoteArgs;
    type PutBallotArgs = Types.PutBallotArgs;
    type Account = Types.Account;
    type SBallotType = Types.SBallotType;
    type PreviewBallotError = Types.PreviewBallotError;
    type Duration = Types.Duration;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type SNewVoteResult = Types.SNewVoteResult;
    type NewVoteError = Types.NewVoteError;
    type SProtocolInfo = Types.SProtocolInfo;
    type SClockParameters = Types.SClockParameters;
    type ClockInfo = Types.ClockInfo;
    type TimerParameters = Types.TimerParameters;
    type STimeline<T> = Types.STimeline<T>;
    type ProtocolParameters = Types.ProtocolParameters;

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

        public func get_amount_minted() : STimeline<Nat> {
            SharedConversions.shareTimeline(controller.get_amount_minted());
        };

        public func get_total_locked() : STimeline<Nat> {
            SharedConversions.shareTimeline(controller.get_total_locked());
        };

        public func get_protocol_parameters() : ProtocolParameters {
            controller.get_protocol_parameters();
        };

        public func get_votes({origin: Principal; filter_ids: ?[UUID] }) : [SVoteType] {
            let vote_types = controller.get_votes({origin; filter_ids;});
            Array.map(vote_types, SharedConversions.shareVoteType);
        };

        public func get_vote_ballots(vote_id: UUID) : [SBallotType] {
            Array.map(controller.get_vote_ballots(vote_id), SharedConversions.shareBallotType);
        };

        public func find_vote({vote_id: UUID;}) : ?SVoteType {
            Option.map(controller.find_vote(vote_id), SharedConversions.shareVoteType);
        };

        public func get_ballots(account: Account) : [SBallotType] {
            Array.map(controller.get_ballots(account), SharedConversions.shareBallotType);
        };

        public func find_ballot(ballot_id: UUID) : ?SBallotType {
            Option.map<BallotType, SBallotType>(controller.find_ballot(ballot_id), SharedConversions.shareBallotType);
        };

        public func current_decay() : Float {
            controller.current_decay();
        };

        public func get_parameters() : SClockParameters {
            SharedConversions.shareClockParameters(controller.get_clock().get_parameters());
        };

        public func clock_info() : ClockInfo {
            controller.get_clock().clock_info();
        };

        public func add_offset(duration: Duration) : Result<(), Text> {
            controller.get_clock().add_offset(duration);
        };

        public func set_dilation_factor(dilation_factor: Float) : Result<(), Text> {
            controller.get_clock().set_dilation_factor(dilation_factor);
        };

        public func get_timer() : ?TimerParameters {
            controller.get_timer();
        };

        public func set_timer({ caller: Principal; duration_s: Nat; }) : async* Result<(), Text> {
            await* controller.set_timer({ caller; duration_s; });
        };

        public func stop_timer({ caller: Principal }) : Result<(), Text> {
            controller.stop_timer({ caller; });
        };

        public func get_time() : Time {
            controller.get_clock().get_time();
        };
        
    };
};
