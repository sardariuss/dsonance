import Types          "Types";
import MigrationTypes "../Types";
import Duration       "../../duration/Duration";
import Timeline       "../../utils/Timeline";

import Map            "mo:map/Map";
import Set            "mo:map/Set";
import BTree          "mo:stableheapbtreemap/BTree";

import Principal      "mo:base/Principal";
import Time           "mo:base/Time";
import Debug          "mo:base/Debug";
import Int            "mo:base/Int";

module {

    type Time          = Int;
    type State         = MigrationTypes.State;
    type Account       = Types.Account;
    type ICRC1         = Types.ICRC1;
    type ICRC2         = Types.ICRC2;
    type InitArgs      = Types.InitArgs;
    type UpgradeArgs   = Types.UpgradeArgs;
    type DowngradeArgs = Types.DowngradeArgs;
    type UUID          = Types.UUID;
    type Lock          = Types.Lock;
    type DebtInfo      = Types.DebtInfo;
    type Ballot<B>     = Types.Ballot<B>;
    type YesNoChoice   = Types.YesNoChoice;
    type VoteType      = Types.VoteType;
    type BallotType    = Types.BallotType;
    type BorrowPosition = Types.BorrowPosition;
    type SupplyPosition = Types.SupplyPosition;
    type Withdrawal     = Types.Withdrawal;
    type DexActor      = Types.DexActor;
    type TrackedPrice  = Types.TrackedPrice;
    type Set<K>        = Set.Set<K>;

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
                timer = {
                    var interval_s = parameters.timer_interval_s;
                };
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
                parameters = parameters.lending;
                state = {
                    var utilization = {
                        raw_supplied = 0.0;
                        raw_borrowed = 0.0;
                        ratio = 0.0;
                    };
                    var borrow_rate = 0.0;
                    var supply_rate = 0.0;
                    var accrued_interests = {
                        fees = 0.0;
                        supply = 0.0;
                    };
                    var borrow_index = 1.0;
                    var supply_index = 1.0;
                    var last_update_timestamp = now;
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

};