import Types "../Types";
import Duration "../duration/Duration";
import RollingTimeline "../utils/RollingTimeline";
import Timeline "../utils/Timeline";

import Option "mo:base/Option";
import Array "mo:base/Array";

module {

    type PositionType = Types.PositionType;
    type SPositionType = Types.SPositionType;
    type Pool<A, B> = Types.Pool<A, B>;
    type SPool<A, B> = Types.SPool<A, B>;
    type Position<B> = Types.Position<B>;
    type SPosition<B> = Types.SPosition<B>;
    type RollingTimeline<T> = Types.RollingTimeline<T>;
    type SRollingTimeline<T> = Types.SRollingTimeline<T>;
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
    type PutPositionSuccess = Types.PutPositionSuccess;
    type SPutPositionSuccess = Types.SPutPositionSuccess;
    type PoolType = Types.PoolType;
    type SPoolType = Types.SPoolType;
    type YieldState = Types.YieldState;
    type SYieldState = Types.SYieldState;
    type LimitOrder<C> = Types.LimitOrder<C>;
    type SLimitOrder<C> = Types.SLimitOrder<C>;
    type LimitOrderType = Types.LimitOrderType;
    type SLimitOrderType = Types.SLimitOrderType;

    public func shareOpt<T, S>(opt: ?T, f: T -> S) : ?S {
        Option.map(opt, f);
    };

    public func sharePositionType(position: PositionType) : SPositionType {
        switch(position){
            case(#YES_NO(position)) { #YES_NO(sharePosition(position)); };
        };
    };

    func sharePosition<B>(position: Position<B>) : SPosition<B> {
        {
            position_id = position.position_id;
            pool_id = position.pool_id;
            timestamp = position.timestamp;
            choice = position.choice;
            amount = position.amount;
            dissent = position.dissent;
            foresight = position.foresight;
            tx_id = position.tx_id;
            supply_index = position.supply_index;
            from = position.from;
            consent = position.consent;
            hotness = position.hotness;
            decay = position.decay;
            lock = Option.map(position.lock, func(lock: LockInfo) : SLockInfo {
                {
                    duration_ns = shareRollingTimeline(lock.duration_ns);
                    release_date = lock.release_date;
                }
            });
        };
    };

    public func shareLimitOrderType(limit_order: LimitOrderType) : SLimitOrderType {
        switch(limit_order){
            case(#YES_NO(order)) { #YES_NO(shareLimitOrder(order)); };
        };
    };

    func shareLimitOrder<C>(limit_order: LimitOrder<C>) : SLimitOrder<C> {
        {
            order_id = limit_order.order_id;
            pool_id = limit_order.pool_id;
            timestamp = limit_order.timestamp;
            account = limit_order.account;
            choice = limit_order.choice;
            amount = limit_order.amount;
            limit_consensus = limit_order.limit_consensus;
        };
    };

    public func shareRollingTimeline<T>(timeline: RollingTimeline<T>) : SRollingTimeline<T> {
        {
            current = timeline.current;
            history = RollingTimeline.history(timeline);
            maxSize = timeline.maxSize;
            minIntervalNs = timeline.minIntervalNs;
        };
    };

    public func shareTimeline<T>(timeline: Timeline<T>) : STimeline<T> {
        {
            current = timeline.current;
            history = timeline.history;
            minIntervalNs = timeline.minIntervalNs;
        };
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
            position_half_life = Duration.fromTime(parameters.position_half_life_ns);
        };
    };

    public func shareDebtInfo(debt_info: DebtInfo) : SDebtInfo {
        {
            id = debt_info.id;
            account = debt_info.account;
            amount = shareRollingTimeline(debt_info.amount);
            transferred = debt_info.transferred;
            transfers = debt_info.transfers;
        };
    };

    public func sharePutPositionSuccess(preview: PutPositionSuccess) : SPutPositionSuccess {
        {
            new = sharePositionType(preview.new);
            previous = Array.map<PositionType, SPositionType>(preview.previous, sharePositionType);
        };
    };

    public func sharePoolType(pool: PoolType) : SPoolType {
        switch(pool){
            case(#YES_NO(v)) { 
                #YES_NO({
                    v with 
                    aggregate = shareRollingTimeline(v.aggregate);
                    tvl = v.tvl;
                });
            };
        };
    };

};