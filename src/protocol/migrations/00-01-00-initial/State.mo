import Types          "Types";
import MigrationTypes "../Types";
import Duration       "../../duration/Duration";
import Timeline       "../../utils/Timeline";
import Clock          "../../utils/Clock";

import Map            "mo:map/Map";
import Set            "mo:map/Set";
import BTree          "mo:stableheapbtreemap/BTree";

import Principal      "mo:base/Principal";
import Time           "mo:base/Time";
import Debug          "mo:base/Debug";
import Int            "mo:base/Int";

module {

    type Time           = Int;
    type State          = MigrationTypes.State;
    type Account        = Types.Account;
    type ICRC1          = Types.ICRC1;
    type ICRC2          = Types.ICRC2;
    type InitArgs       = Types.InitArgs;
    type UpgradeArgs    = Types.UpgradeArgs;
    type DowngradeArgs  = Types.DowngradeArgs;
    type UUID           = Types.UUID;
    type Lock           = Types.Lock;
    type DebtInfo       = Types.DebtInfo;
    type Ballot<B>      = Types.Ballot<B>;
    type YesNoChoice    = Types.YesNoChoice;
    type VoteType       = Types.VoteType;
    type BallotType     = Types.BallotType;
    type BorrowPosition = Types.BorrowPosition;
    type SupplyPosition = Types.SupplyPosition;
    type Withdrawal     = Types.Withdrawal;
    type DexActor       = Types.DexActor;
    type TrackedPrice   = Types.TrackedPrice;
    type Parameters     = Types.Parameters;
    type Set<K>         = Set.Set<K>;

    let BTREE_ORDER = 8;

    public func init(args: InitArgs) : State {

        let { canister_ids; parameters; } = args;
        let now = Int.abs(Time.now());

        #v0_1_0({
            supply_ledger : ICRC1 and ICRC2 = actor(Principal.toText(canister_ids.supply_ledger));
            collateral_ledger : ICRC1 and ICRC2 = actor(Principal.toText(canister_ids.collateral_ledger));
            dex : DexActor = actor(Principal.toText(canister_ids.dex));
            collateral_price_in_supply : TrackedPrice = {
                var value = null;
            };
            collateral_twap_price = {
                var spot_price = null;
                var observations = [];
                var twap_cache = null;
                var last_twap_calculation = 0;
                config = args.parameters.lending.twap_config;
            };
            vote_register = { 
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
                tvl = Timeline.initialize<Nat>(now, 0);
            };
            parameters = { parameters with
                max_age = Duration.toTime(parameters.max_age);
                decay = {
                    half_life = parameters.ballot_half_life;
                    time_init = now;
                };
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
                    local_balance = {
                        var value = 0;
                    };
                };
                collateral = {
                    subaccount = null;
                    local_balance = {
                        var value = 0;
                    };
                };
            };
            lending = {
                index = {
                    var value = {
                        utilization = {
                            raw_supplied = 0.0;
                            raw_borrowed = 0.0;
                            ratio = 0.0;
                        };
                        borrow_rate = 0.0;
                        supply_rate = 0.0;
                        accrued_interests = {
                            fees = 0.0;
                            supply = 0.0;
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
                    };
                };
                register = {
                    borrow_positions = Map.new<Account, BorrowPosition>();
                    supply_positions = Map.new<Text, SupplyPosition>();
                    withdrawals = Map.new<Text, Withdrawal>();
                    withdraw_queue = Set.new<Text>();
                };
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
    public func update(state: State, parameters: Parameters): State {
        
        let v1_state = switch(state) {
            case(#v0_1_0(inner)) { inner; };
        };

        let protocol_parameters = { parameters with
            max_age = Duration.toTime(parameters.max_age);
            decay = {
                half_life = parameters.ballot_half_life;
                // ⚠️ Watchout: Need to keep the initial time from the original parameters, otherwise
                // the decay model will not work correctly.
                time_init = v1_state.parameters.decay.time_init;
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

        #v0_1_0({ v1_state with parameters = protocol_parameters;});
    };

};