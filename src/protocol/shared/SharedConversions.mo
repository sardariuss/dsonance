import Types "../Types";
import Duration "../duration/Duration";

import Option "mo:base/Option";

module {

    type VoteType = Types.VoteType;
    type SVoteType = Types.SVoteType;
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
    type TimerParameters = Types.TimerParameters;
    type STimerParameters = Types.STimerParameters;
    type ProtocolParameters = Types.ProtocolParameters;
    type SProtocolParameters = Types.SProtocolParameters;
    type ProtocolInfo = Types.ProtocolInfo;
    type SProtocolInfo = Types.SProtocolInfo;

    public func shareVoteType(vote_type: VoteType) : SVoteType {
        switch(vote_type){
            case(#YES_NO(vote)) { #YES_NO(shareVote(vote)); };
        };
    };

    public func shareBallotType(ballot: BallotType) : SBallotType {
        switch(ballot){
            case(#YES_NO(ballot)) { #YES_NO(shareBallot(ballot)); };
        };
    };

    func shareVote<A, B>(vote: Vote<A, B>) : SVote<A, B> {
        {
            vote with 
            aggregate = shareTimeline(vote.aggregate);
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
            foresight = shareTimeline(ballot.foresight);
            contribution = shareTimeline(ballot.contribution);
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

    public func shareTimerParameters(timer_parameters: TimerParameters) : STimerParameters {
        { interval_s = timer_parameters.interval_s; };
    };

    public func shareProtocolInfo(protocol_info: ProtocolInfo) : SProtocolInfo {
        {
            current_time = protocol_info.current_time;
            last_run = protocol_info.last_run;
            btc_locked = shareTimeline(protocol_info.btc_locked);
            dsn_minted = shareTimeline(protocol_info.dsn_minted);
        };
    };

    public func shareProtocolParameters(protocol_parameters: ProtocolParameters) : SProtocolParameters {
        {
            protocol_parameters with 
            timer = shareTimerParameters(protocol_parameters.timer);
            clock = shareClockParameters(protocol_parameters.clock);
        };
    };

    public func shareDebtInfo(debt_info: DebtInfo) : SDebtInfo {
        {
            account = debt_info.account;
            amount = shareTimeline(debt_info.amount);
            transferred = debt_info.transferred;
            transfers = debt_info.transfers;
            finalized = debt_info.finalized;
        };
    };

};