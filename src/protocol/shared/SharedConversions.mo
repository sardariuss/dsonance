import Types "../Types";
import Duration "../duration/Duration";

import Option "mo:base/Option";
import Array "mo:base/Array";

module {

    type BallotType = Types.BallotType;
    type SBallotType = Types.SBallotType;
    type Vote<A, B> = Types.Vote<A, B>;
    type SVote<A, B> = Types.SVote<A, B>;
    type Ballot<B> = Types.Ballot<B>;
    type SBallot<B> = Types.SBallot<B>;
    type Timeline<T> = Types.Timeline<T>;
    type STimeline<T> = Types.STimeline<T>;
    type UUID = Types.UUID;
    type DebtInfo = Types.DebtInfo;
    type SDebtInfo = Types.SDebtInfo;
    type LockInfo = Types.LockInfo;
    type SLockInfo = Types.SLockInfo;
    type ClockParameters = Types.ClockParameters;
    type SClockParameters = Types.SClockParameters;
    type MinterParameters = Types.MinterParameters;
    type SMinterParameters = Types.SMinterParameters;
    type Parameters = Types.Parameters;
    type SParameters = Types.SParameters;
    type ProtocolInfo = Types.ProtocolInfo;
    type PutBallotSuccess = Types.PutBallotSuccess;
    type SPutBallotSuccess = Types.SPutBallotSuccess;
    type VoteType = Types.VoteType;
    type SVoteType = Types.SVoteType;
    type YieldState = Types.YieldState;
    type SYieldState = Types.SYieldState;

    public func shareOpt<T, S>(opt: ?T, f: T -> S) : ?S {
        Option.map(opt, f);
    };

    public func shareBallotType(ballot: BallotType) : SBallotType {
        switch(ballot){
            case(#YES_NO(ballot)) { #YES_NO(shareBallot(ballot)); };
        };
    };

    func shareBallot<B>(ballot: Ballot<B>) : SBallot<B> {
        {
            ballot_id = ballot.ballot_id;
            vote_id = ballot.vote_id;
            timestamp = ballot.timestamp;
            choice = ballot.choice;
            amount = ballot.amount;
            dissent = ballot.dissent;
            consent = shareTimeline(ballot.consent);
            foresight = ballot.foresight;
            tx_id = ballot.tx_id;
            from = ballot.from;
            hotness = ballot.hotness;
            decay = ballot.decay;
            lock = Option.map(ballot.lock, func(lock: LockInfo) : SLockInfo {
                {
                    duration_ns = shareTimeline(lock.duration_ns);
                    release_date = lock.release_date;
                }
            });
        };
    };

    public func shareTimeline<T>(history: Timeline<T>) : STimeline<T> {
        { current = history.current; history = history.history; };
    };

    public func shareClockParameters(clock_parameters: ClockParameters) : SClockParameters {
        switch(clock_parameters){
            case(#REAL) { #REAL; };
            case(#SIMULATED(p)) { #SIMULATED({ time_ref = p.time_ref; offset = Duration.fromTime(p.offset_ns); dilation_factor = p.dilation_factor; }); };
        };
    };

    public func shareMinterParameters(minter_parameters: MinterParameters) : SMinterParameters {
        {
            contribution_per_day = minter_parameters.contribution_per_day;
            author_share = minter_parameters.author_share;
            time_last_mint = minter_parameters.time_last_mint;
            amount_minted = shareTimeline(minter_parameters.amount_minted);
        };
    };

    public func shareParameters(parameters: Parameters) : SParameters {
        {
            parameters with
            clock = shareClockParameters(parameters.clock);
            twap_config = {
                window_duration = Duration.fromTime(parameters.twap_config.window_duration_ns);
                max_observations = parameters.twap_config.max_observations;
            };
            max_age = Duration.fromTime(parameters.max_age);
            decay = {
                half_life = parameters.decay.half_life;
                time_init = parameters.decay.time_init;
            };
        };
    };

    public func shareDebtInfo(debt_info: DebtInfo) : SDebtInfo {
        {
            id = debt_info.id;
            account = debt_info.account;
            amount = shareTimeline(debt_info.amount);
            transferred = debt_info.transferred;
            transfers = debt_info.transfers;
        };
    };

    public func sharePutBallotSuccess(preview: PutBallotSuccess) : SPutBallotSuccess {
        {
            new = shareBallotType(preview.new);
            previous = Array.map<BallotType, SBallotType>(preview.previous, shareBallotType);
        };
    };

    public func shareVoteType(vote: VoteType) : SVoteType {
        switch(vote){
            case(#YES_NO(v)) { 
                #YES_NO({
                    v with 
                    aggregate = shareTimeline(v.aggregate);
                    tvl = v.tvl;
                });
            };
        };
    };

};