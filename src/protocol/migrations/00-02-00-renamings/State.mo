import V0_2_0         "Types";
import V0_1_0         "../00-01-00-initial/Types";
import Duration       "../../duration/Duration";
import RollingTimeline "../../utils/RollingTimeline";
import Timeline       "../../utils/Timeline";

import Map            "mo:map/Map";
import Set            "mo:map/Set";
import BTree          "mo:stableheapbtreemap/BTree";

import Principal      "mo:base/Principal";
import Time           "mo:base/Time";
import Int            "mo:base/Int";
import Text           "mo:base/Text";
import Debug          "mo:base/Debug";

// Version 0.2.0 changes:
// - Renaming VoteType to PoolType
// - Renaming BallotType to PositionType
// - SupplyPosition becomes RedistributionPosition and SupplyRegister becomes RedistributionRegister
// - Add total_supplied, total_raw and index to RedistributionRegister, remove interests from LendingIndex
// - Add new account-based SupplyPosition and SupplyRegister for indexed supply positions
module {

    type Time                   = Int;
    type Account                = V0_2_0.Account;
    type ICRC1                  = V0_2_0.ICRC1;
    type ICRC2                  = V0_2_0.ICRC2;
    type MiningTracker          = V0_2_0.MiningTracker;
    type UUID                   = V0_2_0.UUID;
    type Lock                   = V0_2_0.Lock;
    type DebtInfo               = V0_2_0.DebtInfo;
    type Position<B>            = V0_2_0.Position<B>;
    type YesNoChoice            = V0_2_0.YesNoChoice;
    type PoolType               = V0_2_0.PoolType;
    type PositionType           = V0_2_0.PositionType;
    type BorrowPosition         = V0_2_0.BorrowPosition;
    type SupplyPosition         = V0_2_0.SupplyPosition;
    type RedistributionPosition = V0_2_0.RedistributionPosition;
    type Withdrawal             = V0_2_0.Withdrawal;
    type KongBackendActor       = V0_2_0.KongBackendActor;
    type XrcActor               = V0_2_0.XrcActor;
    type TrackedPrice           = V0_2_0.TrackedPrice;
    type Parameters             = V0_2_0.Parameters;
    type InitParameters         = V0_2_0.InitParameters;
    type LendingIndex           = V0_2_0.LendingIndex;
    type LimitOrderBTreeKey     = V0_2_0.LimitOrderBTreeKey;
    type LendingRegister        = V0_2_0.LendingRegister;
    type LimitOrderType         = V0_2_0.LimitOrderType;
    type Set<K>                 = Set.Set<K>;

    public type State           = V0_2_0.State;
    public type Args            = V0_2_0.Args;

    let BTREE_ORDER = 8;

    public func init(args: Args) : State {

        let init_args = switch(args) {
            case(#init(inner)) { inner; };
            case(#migrate) { Debug.trap("Migrate args not supported in init"); };
        };

        let { canister_ids; parameters; } = init_args;
        let now = Int.abs(Time.now());

        {
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
            positions = Map.new<UUID, PositionType>();
            limit_orders = Map.new<UUID, LimitOrderType>();
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
                clock : V0_2_0.ClockParameters = switch(parameters.clock) {
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
                index = Timeline.make1h<V0_2_0.LendingIndex>(now, {
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
                    supply_positions = Map.new<Account, SupplyPosition>();
                    redistribution_positions = Map.new<Text, RedistributionPosition>();
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
        };
    };

    // From 0.1.0 to 0.2.0
    // The previous migration pattern used to be meant to be used for classical orthogonal persistence.
    // But now enhanced orthogonal persistence is used, so the wrapping in a variant does not apply anymore.
    public func migration(old : { var state : { #v0_1_0: V0_1_0.State } }) : { var state : State  } {

        let v1_state = switch(old.state) {
            case(#v0_1_0(inner)) { inner; };
        };

        // Transform VoteType to PoolType
        func transformVoteToPool(poolType: V0_1_0.VoteType): PoolType {
            switch(poolType) {
                case(#YES_NO(pool)) {
                    #YES_NO({
                        pool_id = pool.vote_id;
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
                        pool_id = ballot.vote_id;
                        timestamp = ballot.timestamp;
                        choice = ballot.choice;
                        amount = ballot.amount;
                        dissent = ballot.dissent;
                        tx_id = ballot.tx_id;
                        from = ballot.from;
                        decay = ballot.decay;
                        supply_index = ballot.supply_index;
                        var consent = ballot.consent.current.data; // Extract current consent value
                        var foresight = ballot.foresight;
                        var hotness = ballot.hotness;
                        var lock = ballot.lock;
                    });
                };
            };
        };

        // Transform the Maps
        let new_pools = Map.new<UUID, PoolType>();
        for ((uuid, poolType) in Map.entries(v1_state.vote_register.votes)) {
            Map.set(new_pools, Map.thash, uuid, transformVoteToPool(poolType));
        };

        let new_positions = Map.new<UUID, PositionType>();
        for ((uuid, ballotType) in Map.entries(v1_state.ballot_register.ballots)) {
            Map.set(new_positions, Map.thash, uuid, transformBallotToPosition(ballotType));
        };

        {
            var state = {
                genesis_time = v1_state.genesis_time;
                supply_ledger = v1_state.supply_ledger;
                collateral_ledger = v1_state.collateral_ledger;
                participation_ledger = v1_state.participation_ledger;
                kong_backend = v1_state.kong_backend;
                xrc = v1_state.xrc;
                collateral_twap_price = v1_state.collateral_twap_price;
                pool_register = {
                    pools = new_pools;
                    by_origin = v1_state.vote_register.by_origin;
                    by_author = v1_state.vote_register.by_author;
                };
                positions = new_positions;
                // Limit orders have been introduced in this version
                limit_orders = Map.new<UUID, LimitOrderType>();
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
                        supply_positions = Map.new<Account, SupplyPosition>();
                        redistribution_positions = v1_state.lending.register.supply_positions;
                        var total_supplied = v1_state.lending.index.current.data.utilization.raw_supplied;
                        var total_raw = v1_state.lending.index.current.data.utilization.raw_supplied + v1_state.lending.index.current.data.accrued_interests.supply;
                        var index = v1_state.lending.index.current.data.supply_index.value;
                        withdrawals = v1_state.lending.register.withdrawals;
                        withdraw_queue = v1_state.lending.register.withdraw_queue;
                    };
                };
                mining = v1_state.mining;
            };
        };
    };

};
