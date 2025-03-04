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
import Float          "mo:base/Float";
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

    let BTREE_ORDER = 8;

    public func init(args: InitArgs) : State {

        let { btc; dsn; parameters; } = args;
        let now = Int.abs(Time.now());

        #v0_1_0({
            vote_register = { 
                votes = Map.new<UUID, VoteType>();
                by_origin = Map.new<Principal, Set.Set<UUID>>();
            };
            ballot_register = {
                ballots = Map.new<UUID, BallotType>();
                by_account = Map.new<Account, Set.Set<UUID>>();
            };
            lock_register = {
                var time_last_dispense = now;
                total_amount = Timeline.initialize(now, 0);
                locks = BTree.init<Lock, Ballot<YesNoChoice>>(?BTREE_ORDER);
                yield = {
                    rate = 0.1; // TODO: This parameter shall be variable and come from the lending/borrowing utilization rate
                    var cumulated = 0;
                    contributions = {
                        var sum_current = 0;
                        var sum_cumulated = 0;
                    };
                };
            };
            btc = {
                ledger : ICRC1 and ICRC2 = actor(Principal.toText(btc.ledger));
                fee = btc.fee;
                owed = Set.new<UUID>();
            };
            dsn = {
                ledger : ICRC1 and ICRC2 = actor(Principal.toText(dsn.ledger));
                fee = dsn.fee;
                owed = Set.new<UUID>();
            };
            parameters = { parameters with
                contribution_per_ns = Float.fromInt(parameters.contribution_per_day) / Float.fromInt(Duration.NS_IN_DAY);
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
            minting_info = {
                amount_minted = Timeline.initialize<Nat>(now, 0);
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