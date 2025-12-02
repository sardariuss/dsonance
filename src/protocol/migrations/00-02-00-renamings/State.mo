import Types          "Types";
import V0_1_0         "../00-01-00-initial/Types";
import MigrationTypes "../Types";
import Duration       "../../duration/Duration";
import Clock          "../../utils/Clock";
import RollingTimeline "../../utils/RollingTimeline";
import Timeline       "../../utils/Timeline";

import Array          "mo:base/Array";
import Map            "mo:map/Map";
import Set            "mo:map/Set";
import BTree          "mo:stableheapbtreemap/BTree";

import Principal      "mo:base/Principal";
import Time           "mo:base/Time";
import Debug          "mo:base/Debug";
import Int            "mo:base/Int";
import Text           "mo:base/Text";

module {

    type Time               = Int;
    type State              = MigrationTypes.State;
    type Account            = Types.Account;
    type ICRC1              = Types.ICRC1;
    type ICRC2              = Types.ICRC2;
    type MiningTracker      = Types.MiningTracker;
    type InitArgs           = Types.InitArgs;
    type UpgradeArgs        = Types.UpgradeArgs;
    type DowngradeArgs      = Types.DowngradeArgs;
    type UUID               = Types.UUID;
    type Lock               = Types.Lock;
    type DebtInfo           = Types.DebtInfo;
    type Position<B>        = Types.Position<B>;
    type YesNoChoice        = Types.YesNoChoice;
    type PoolType           = Types.PoolType;
    type PositionType       = Types.PositionType;
    type BorrowPosition     = Types.BorrowPosition;
    type SupplyPosition     = Types.SupplyPosition;
    type Withdrawal         = Types.Withdrawal;
    type KongBackendActor   = Types.KongBackendActor;
    type XrcActor           = Types.XrcActor;
    type TrackedPrice       = Types.TrackedPrice;
    type Parameters         = Types.Parameters;
    type InitParameters     = Types.InitParameters;
    type LendingIndex       = Types.LendingIndex;
    type LimitOrderBTreeKey = Types.LimitOrderBTreeKey;
    type Set<K>             = Set.Set<K>;

    let BTREE_ORDER = 8;

    public func init(args: InitArgs) : State {

        let { canister_ids; parameters; } = args;
        let now = Int.abs(Time.now());

        #v0_2_0({
            genesis_time = now;
            supply_ledger : ICRC1 and ICRC2 = actor(Principal.toText(canister_ids.supply_ledger));
            collateral_ledger : ICRC1 and ICRC2 = actor(Principal.toText(canister_ids.collateral_ledger));
            participation_ledger : ICRC1 and ICRC2 = actor(Principal.toText(canister_ids.participation_ledger));
            kong_backend : KongBackendActor = actor(Principal.toText(canister_ids.kong_backend));
            xrc : XrcActor = actor(Principal.toText(canister_ids.xrc));
            collateral_twap_price = {
                var spot_price = null;
                var observations = [];
                var twap_cache = null;
                var last_twap_calculation = 0;
            };
            pool_register = {
                pools = Map.new<UUID, PoolType>();
                by_origin = Map.new<Principal, Set<UUID>>();
                by_author = Map.new<Account, Set<UUID>>();
            };
            position_register = {
                positions = Map.new<UUID, PositionType>();
                by_account = Map.new<Account, Set<UUID>>();
            };
            lock_scheduler_state = {
                btree = BTree.init<Lock, ()>(?BTREE_ORDER);
                map = Map.new<Text, Lock>();
            };
            parameters = { parameters with
                twap_config = {
                    window_duration_ns = Duration.toTime(parameters.twap_config.window_duration);
                    max_observations = parameters.twap_config.max_observations;
                };
                mining = { parameters.mining with
                    emission_half_life_s = Duration.toSeconds(parameters.mining.emission_half_life);
                };
                position_half_life_ns = Duration.toTime(parameters.position_half_life);
                clock : Types.ClockParameters = switch(parameters.clock) {
                    case(#REAL) { #REAL; };
                    case(#SIMULATED({ dilation_factor; })) {
                        #SIMULATED({
                            var time_ref = now;
                            var offset_ns = 0;
                            var dilation_factor = dilation_factor;
                        });
                    };
                };
            };
            accounts = {
                supply = {
                    subaccount = null;
                    fees_subaccount = Text.encodeUtf8("LENDING_FEES");
                    unclaimed_fees = {
                        var value = 0;
                    };
                };
                collateral = {
                    subaccount = null;
                };
            };
            lending = {
                index = Timeline.make1h<Types.LendingIndex>(now, {
                    utilization = {
                        raw_supplied = 0.0;
                        raw_borrowed = 0.0;
                        ratio = 0.0;
                    };
                    borrow_rate = 0.0;
                    supply_rate = 0.0;
                    borrow_index = {
                        value = 1.0;
                        timestamp = now;
                    };
                    supply_index =  {
                        value = 1.0;
                        timestamp = now;
                    };
                    timestamp = now;
                });
                register = {
                    borrow_positions = Map.new<Account, BorrowPosition>();
                    supply_positions = Map.new<Text, SupplyPosition>();
                    var total_supplied = 0.0;
                    var total_raw = 0.0;
                    var index = 1.0;
                    withdrawals = Map.new<Text, Withdrawal>();
                    withdraw_queue = Set.new<Text>();

                };
            };
            mining = {
                var last_mint_timestamp = now;
                tracking = Map.new<Account, MiningTracker>();
                total_allocated = RollingTimeline.make1h4y<Nat>(now, 0);
                total_claimed = RollingTimeline.make1h4y<Nat>(now, 0);
            };
        });
    };

    // From 0.1.0 to 0.2.0
    public func upgrade(state: State, _: UpgradeArgs): State {

        let v1_state = switch(state) {
            case(#v0_1_0(inner)) { inner; };
            case(_) { Debug.trap("Cannot upgrade from non-v0.1.0 state"); };
        };

        // Transform VoteType to PoolType
        func transformVoteToPool(poolType: V0_1_0.VoteType): PoolType {
            switch(poolType) {
                case(#YES_NO(pool)) {
                    #YES_NO({
                        pool_id = pool.pool_id;
                        tx_id = pool.tx_id;
                        date = pool.date;
                        origin = pool.origin;
                        aggregate = pool.aggregate;
                        positions = pool.ballots;
                        author = pool.author;
                        descending_orders = Map.new<YesNoChoice, BTree.BTree<LimitOrderBTreeKey, UUID>>();
                        var tvl = pool.tvl;
                    });
                };
            };
        };

        // Transform BallotType to PositionType
        func transformBallotToPosition(ballotType: V0_1_0.BallotType): PositionType {
            switch(ballotType) {
                case(#YES_NO(ballot)) {
                    #YES_NO({
                        position_id = ballot.ballot_id;
                        pool_id = ballot.pool_id;
                        timestamp = ballot.timestamp;
                        choice = ballot.choice;
                        amount = ballot.amount;
                        dissent = ballot.dissent;
                        consent = ballot.consent;
                        tx_id = ballot.tx_id;
                        from = ballot.from;
                        decay = ballot.decay;
                        supply_index = ballot.supply_index;
                        var foresight = ballot.foresight;
                        var hotness = ballot.hotness;
                        var lock = ballot.lock;
                    });
                };
            };
        };

        // Transform the Maps
        let new_pools = Map.new<UUID, PoolType>();
        for ((uuid, poolType) in Map.entries(v1_state.pool_register.pools)) {
            Map.set(new_pools, Map.thash, uuid, transformVoteToPool(poolType));
        };

        let new_positions = Map.new<UUID, PositionType>();
        for ((uuid, ballotType) in Map.entries(v1_state.ballot_register.ballots)) {
            Map.set(new_positions, Map.thash, uuid, transformBallotToPosition(ballotType));
        };

        #v0_2_0({
            genesis_time = v1_state.genesis_time;
            supply_ledger = v1_state.supply_ledger;
            collateral_ledger = v1_state.collateral_ledger;
            participation_ledger = v1_state.participation_ledger;
            kong_backend = v1_state.kong_backend;
            xrc = v1_state.xrc;
            collateral_twap_price = v1_state.collateral_twap_price;
            pool_register = {
                pools = new_pools;
                by_origin = v1_state.pool_register.by_origin;
                by_author = v1_state.pool_register.by_author;
            };
            position_register = {
                positions = new_positions;
                by_account = v1_state.ballot_register.by_account;
            };
            lock_scheduler_state = v1_state.lock_scheduler_state;
            parameters = { v1_state.parameters with
                position_half_life_ns = v1_state.parameters.ballot_half_life_ns;
                minimum_position_amount = v1_state.parameters.minimum_ballot_amount;
            };
            accounts = v1_state.accounts;
            lending = {
                index = {
                    var current = v1_state.lending.index.current;
                    var history = v1_state.lending.index.history;
                    var lastCheckpointTimestamp = v1_state.lending.index.lastCheckpointTimestamp;
                    minIntervalNs = v1_state.lending.index.minIntervalNs;
                };
                register = {
                    borrow_positions = v1_state.lending.register.borrow_positions;
                    supply_positions = v1_state.lending.register.supply_positions;
                    var total_supplied = 0.0; // TODO: should come from lendingindex 
                    var total_raw = 0.0;
                    var index = 1.0;
                    withdrawals = v1_state.lending.register.withdrawals;
                    withdraw_queue = v1_state.lending.register.withdraw_queue;
                };
            };
            mining = v1_state.mining;
        });
    };

    // From 0.2.0 to 0.1.0
    public func downgrade(state: State, _: DowngradeArgs): State {

        let v2_state = switch(state) {
            case(#v0_2_0(inner)) { inner; };
            case(_) { Debug.trap("Cannot downgrade from non-v0.2.0 state"); };
        };

        // Transform PoolType back to VoteType
        func transformPoolToVote(poolType: PoolType): V0_1_0.VoteType {
            switch(poolType) {
                case(#YES_NO(pool)) {
                    #YES_NO({
                        pool_id = pool.pool_id;
                        tx_id = pool.tx_id;
                        date = pool.date;
                        origin = pool.origin;
                        aggregate = pool.aggregate;
                        ballots = pool.positions;
                        author = pool.author;
                        var tvl = pool.tvl;
                    });
                };
            };
        };

        // Transform PositionType back to BallotType
        func transformPositionToBallot(positionType: PositionType): V0_1_0.BallotType {
            switch(positionType) {
                case(#YES_NO(position)) {
                    #YES_NO({
                        ballot_id = position.position_id;
                        pool_id = position.pool_id;
                        timestamp = position.timestamp;
                        choice = position.choice;
                        amount = position.amount;
                        dissent = position.dissent;
                        consent = position.consent;
                        tx_id = position.tx_id;
                        from = position.from;
                        decay = position.decay;
                        supply_index = position.supply_index;
                        var foresight = position.foresight;
                        var hotness = position.hotness;
                        var lock = position.lock;
                    });
                };
            };
        };

        // Transform the Maps back
        let old_pools = Map.new<UUID, V0_1_0.VoteType>();
        for ((uuid, poolType) in Map.entries(v2_state.pool_register.pools)) {
            Map.set(old_pools, Map.thash, uuid, transformPoolToVote(poolType));
        };

        let old_ballots = Map.new<UUID, V0_1_0.BallotType>();
        for ((uuid, positionType) in Map.entries(v2_state.position_register.positions)) {
            Map.set(old_ballots, Map.thash, uuid, transformPositionToBallot(positionType));
        };

        #v0_1_0({
            genesis_time = v2_state.genesis_time;
            supply_ledger = v2_state.supply_ledger;
            collateral_ledger = v2_state.collateral_ledger;
            participation_ledger = v2_state.participation_ledger;
            kong_backend = v2_state.kong_backend;
            xrc = v2_state.xrc;
            collateral_twap_price = v2_state.collateral_twap_price;
            pool_register = {
                pools = old_pools;
                by_origin = v2_state.pool_register.by_origin;
                by_author = v2_state.pool_register.by_author;
            };
            ballot_register = {
                ballots = old_ballots;
                by_account = v2_state.position_register.by_account;
            };
            lock_scheduler_state = v2_state.lock_scheduler_state;
            parameters = { v2_state.parameters with
                ballot_half_life_ns = v2_state.parameters.position_half_life_ns;
                minimum_ballot_amount = v2_state.parameters.minimum_position_amount;
            };
            accounts = v2_state.accounts;
            lending = {
                index = {
                    var current = {
                        data = downgrade_lending_index(v2_state.lending.index.current.data);
                        timestamp = v2_state.lending.index.current.timestamp;
                    };
                    var history = Array.map<Types.TimedData<LendingIndex>, V0_1_0.TimedData<V0_1_0.LendingIndex>>(v2_state.lending.index.history, func(item) {
                        {
                            data = downgrade_lending_index(item.data);
                            timestamp = item.timestamp;
                        };
                    });
                    var lastCheckpointTimestamp = v2_state.lending.index.lastCheckpointTimestamp;
                    minIntervalNs = v2_state.lending.index.minIntervalNs;
                };
                register = {
                    borrow_positions = v2_state.lending.register.borrow_positions;
                    supply_positions = v2_state.lending.register.supply_positions;
                    withdrawals = v2_state.lending.register.withdrawals;
                    withdraw_queue = v2_state.lending.register.withdraw_queue;
                };
            };
            mining = v2_state.mining;
        });
    };

    // From 0.2.0 to 0.2.0, with new parameters
    public func update(state: State, parameters: InitParameters): State {

        let v2_state = switch(state) {
            case(#v0_2_0(inner)) { inner; };
            case(_) { Debug.trap("Cannot update non-v0.2.0 state"); };
        };

        let protocol_parameters = { parameters with
            twap_config = {
                window_duration_ns = Duration.toTime(parameters.twap_config.window_duration);
                max_observations = parameters.twap_config.max_observations;
            };
            position_half_life_ns = Duration.toTime(parameters.position_half_life);
            mining = { parameters.mining with
                emission_half_life_s = Duration.toSeconds(parameters.mining.emission_half_life);
            };
            clock : Types.ClockParameters = switch(parameters.clock) {
                case(#REAL) { #REAL; };
                case(#SIMULATED({ dilation_factor; })) {
                    let now = Int.abs(Time.now());
                    // ⚠️ Watchout: If the previous clock was simulated, we need to keep the time reference and offset
                    // from the original parameters, otherwise there might be a gap or interesction in the time.
                    switch(v2_state.parameters.clock) {
                        case(#REAL) {
                            #SIMULATED({
                                var time_ref = now;
                                var offset_ns = 0;
                                var dilation_factor = dilation_factor;
                            });
                        };
                        case(#SIMULATED(previous_clock)) {
                            // If the previous clock was simulated, we need to compute the new offset
                            // based on the current time and the previous time reference and dilation factor.
                            let offset_ns = previous_clock.offset_ns
                                + Clock.compute_dilatation(now, previous_clock.time_ref, previous_clock.dilation_factor);
                            #SIMULATED({
                                var time_ref = previous_clock.time_ref;
                                var offset_ns = offset_ns;
                                var dilation_factor = dilation_factor;
                            });
                        };
                    };
                };
            };
        };

        #v0_2_0({ v2_state with parameters = protocol_parameters; });
    };

    func downgrade_lending_index(index: LendingIndex): V0_1_0.LendingIndex {
        {
            utilization = index.utilization;
            borrow_rate = index.borrow_rate;
            supply_rate = index.supply_rate;
            // accrued_interests field removed, use default values
            accrued_interests = { supply = 0.0; borrow = 0.0; };
            borrow_index = index.borrow_index;
            supply_index = index.supply_index;
            timestamp = index.timestamp;
        };
    };

};
