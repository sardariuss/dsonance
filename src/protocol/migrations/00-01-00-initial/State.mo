import Types          "Types";
import Duration       "../../duration/Duration";
import Clock          "../../utils/Clock";
import RollingTimeline "../../utils/RollingTimeline";
import Timeline       "../../utils/Timeline";

import Map            "mo:map/Map";
import Set            "mo:map/Set";
import BTree          "mo:stableheapbtreemap/BTree";

import Principal      "mo:base/Principal";
import Time           "mo:base/Time";
import Debug          "mo:base/Debug";
import Int            "mo:base/Int";
import Text           "mo:base/Text";

module {

    type Time             = Int;
    type Account          = Types.Account;
    type ICRC1            = Types.ICRC1;
    type ICRC2            = Types.ICRC2;
    type MiningTracker    = Types.MiningTracker;
    type InitArgs         = Types.InitArgs;
    type UpgradeArgs      = Types.UpgradeArgs;
    type DowngradeArgs    = Types.DowngradeArgs;
    type UUID             = Types.UUID;
    type Lock             = Types.Lock;
    type DebtInfo         = Types.DebtInfo;
    type Ballot<B>        = Types.Ballot<B>;
    type YesNoChoice      = Types.YesNoChoice;
    type VoteType         = Types.VoteType;
    type BallotType       = Types.BallotType;
    type BorrowPosition   = Types.BorrowPosition;
    type SupplyPosition   = Types.SupplyPosition;
    type Withdrawal       = Types.Withdrawal;
    type KongBackendActor = Types.KongBackendActor;
    type XrcActor         = Types.XrcActor;
    type TrackedPrice     = Types.TrackedPrice;
    type Parameters       = Types.Parameters;
    type InitParameters   = Types.InitParameters;
    type LendingIndex     = Types.LendingIndex;
    type Set<K>           = Set.Set<K>;

    // Used to come from ../Types.mo when old migration pattern (meant for classical orthogonal persistence) was used
    type State = {
        #v0_1_0: Types.State;
    };

    let BTREE_ORDER = 8;

    public func init(args: InitArgs) : State {

        let { canister_ids; parameters; } = args;
        let now = Int.abs(Time.now());

        #v0_1_0({
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
                votes = Map.new<UUID, VoteType>();
                by_origin = Map.new<Principal, Set<UUID>>();
                by_author = Map.new<Account, Set<UUID>>();
            };
            ballot_register = {
                ballots = Map.new<UUID, BallotType>();
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
                ballot_half_life_ns = Duration.toTime(parameters.ballot_half_life);
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
                    accrued_interests = {
                        supply = 0.0;
                        borrow = 0.0;
                    };
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

    // From nothing to 0.1.0
    public func upgrade(_: State, _: UpgradeArgs): State {
        Debug.trap("Cannot upgrade to initial version");
    };

    // From 0.1.0 to nothing
    public func downgrade(_: State, _: DowngradeArgs): State {
        Debug.trap("Cannot downgrade from initial version");
    };

    // From 0.1.0 to 0.1.0, with new parameters
    public func update(state: State, parameters: InitParameters): State {
        
        let v1_state = switch(state) {
            case(#v0_1_0(inner)) { inner; };
        };

        let protocol_parameters = { parameters with
            twap_config = {
                window_duration_ns = Duration.toTime(parameters.twap_config.window_duration);
                max_observations = parameters.twap_config.max_observations;
            };
            ballot_half_life_ns = Duration.toTime(parameters.ballot_half_life);
            mining = { parameters.mining with
                emission_half_life_s = Duration.toSeconds(parameters.mining.emission_half_life);
            };
            clock : Types.ClockParameters = switch(parameters.clock) {
                case(#REAL) { #REAL; };
                case(#SIMULATED({ dilation_factor; })) {
                    let now = Int.abs(Time.now());
                    // ⚠️ Watchout: If the previous clock was simulated, we need to keep the time reference and offset
                    // from the original parameters, otherwise there might be a gap or interesction in the time.
                    switch(v1_state.parameters.clock) {
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

        #v0_1_0({ v1_state with parameters = protocol_parameters; });
    };

};