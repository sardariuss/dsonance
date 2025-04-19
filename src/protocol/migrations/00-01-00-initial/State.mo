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
    type Set<K>        = Set.Set<K>;

    let BTREE_ORDER = 8;

    public func init(args: InitArgs) : State {

        let { btc; dsn; minter; parameters; } = args;
        let now = Int.abs(Time.now());

        #v0_1_0({
            vote_register = { 
                votes = Map.new<UUID, VoteType>();
                by_origin = Map.new<Principal, Set<UUID>>();
                by_author = Map.new<Account, Set<UUID>>();
            };
            ballot_register = {
                ballots = Map.new<UUID, BallotType>();
                by_account = Map.new<Account, Set<UUID>>();
            };
            btc = {
                ledger : ICRC1 and ICRC2 = actor(Principal.toText(btc.ledger));
                fee = btc.fee;
                debt_register = {
                    debts = Map.new<UUID, DebtInfo>();
                    pending_transfer = Set.new<UUID>();
                };
            };
            dsn = {
                ledger : ICRC1 and ICRC2 = actor(Principal.toText(dsn.ledger));
                fee = dsn.fee;
                debt_register = {
                    debts = Map.new<UUID, DebtInfo>();
                    pending_transfer = Set.new<UUID>();
                };
            };
            lock_scheduler_state = {
                btree = BTree.init<Lock, ()>(?BTREE_ORDER);
                map = Map.new<Text, Lock>();
                tvl = Timeline.initialize<Nat>(now, 0);
            };
            yield_state = {
                var tvl = 0;
                var apr = 10;
                interest = {
                    var earned = 0;
                    var time_last_update = now;
                };
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
                minter_parameters = {
                    var contribution_per_day = minter.contribution_per_day;
                    var author_share = minter.author_share;
                    var time_last_mint = now; // @todo: shall be null instead
                    amount_minted = Timeline.initialize<Float>(now, 0);
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