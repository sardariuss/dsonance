import Types                  "Types";
import Controller             "Controller";
import Yielder                "Yielder";
import Queries                "Queries";
import Decay                  "duration/Decay";
import DurationCalculator     "duration/DurationCalculator";
import VoteFactory            "votes/VoteFactory";
import VoteTypeController     "votes/VoteTypeController";
import LockInfoUpdater        "locks/LockInfoUpdater";
import LedgerFacade           "payement/LedgerFacade";
import LockScheduler          "LockScheduler2";
import Clock                  "utils/Clock";
import Timeline               "utils/Timeline";
import DebtProcessor          "DebtProcessor";
import TokenMinter            "TokenMinter"; 
import IterUtils              "utils/Iter";
import ForesightUpdater       "ForesightUpdater";
import BallotUtils            "votes/BallotUtils";
import Incentives             "votes/Incentives";

import Debug                  "mo:base/Debug";
import Map                    "mo:map/Map";

module {

    type State       = Types.State;
    type YesNoBallot = Types.YesNoBallot;
    type YesNoVote   = Types.YesNoVote;
    type Lock        = Types.Lock; 
    type UUID        = Types.UUID;
    type DebtInfo    = Types.DebtInfo;
    type LockEvent   = Types.LockEvent;
    type BallotType  = Types.BallotType;
    
    type Iter<T>     = Map.Iter<T>;
    type Time        = Int;

    public func build(args: State and { provider: Principal; admin: Principal; }) : Controller.Controller {

        let { vote_register; ballot_register; lock_register; lock_scheduler_state; btc; dsn; parameters; provider; yield_state; } = args;
        let { nominal_lock_duration; decay; minter_parameters; } = parameters;

        let btc_ledger = LedgerFacade.LedgerFacade({ btc with provider; });
        let dsn_ledger = LedgerFacade.LedgerFacade({ dsn with provider; });

        let clock = Clock.Clock(parameters.clock);

        let btc_debt = DebtProcessor.DebtProcessor({
            ledger = btc_ledger;
            register = btc.debt_register;
        });

        let dsn_debt = DebtProcessor.DebtProcessor({
            ledger = dsn_ledger;
            register = dsn.debt_register;
        });

        let minter = TokenMinter.TokenMinter({
            parameters = minter_parameters;
            dsn_debt;
            get_tvl = func() : Nat { Timeline.current(lock_scheduler_state.tvl) };
            get_locked_ballots = func () : Iter<(YesNoBallot, YesNoVote)> {
                IterUtils.map<Lock, (YesNoBallot, YesNoVote)>(Map.vals(lock_scheduler_state.map), func(lock: Lock) : (YesNoBallot, YesNoVote) {
                    let ballot = switch(Map.get(ballot_register.ballots, Map.thash, lock.id)){
                        case(null) { Debug.trap("Ballot not found"); };
                        case(?(#YES_NO(b))) { b; };
                    };
                    let vote = switch(Map.get(vote_register.votes, Map.thash, ballot.vote_id)){
                        case(null) { Debug.trap("Vote not found"); };
                        case(?(#YES_NO(v))) { v; };
                    };
                    (ballot, vote);
                });
            };
        });

        let yielder = Yielder.Yielder(yield_state);

        let foresight_updater = ForesightUpdater.ForesightUpdater({
            ballots = Map.map(ballot_register.ballots, Map.thash, func(_: Text, b: BallotType) : YesNoBallot {
                switch(b){
                    case(#YES_NO(ballot)) { ballot };
                };
            });
            compute_discernment = func(b: YesNoBallot) {
                let lock = BallotUtils.unwrap_lock_info(b);
                Incentives.compute_discernment({
                    dissent = b.dissent;
                    consent = Timeline.current(b.consent);
                    lock_duration = lock.release_date - b.timestamp;
                    parameters;
                });
            };
            get_yield = func () : { earned: Float; apr: Float; tvl: Nat; } {
                {
                    earned = yield_state.interest.earned;
                    apr = yield_state.apr;
                    tvl = yield_state.tvl;
                }
            };
        });
        
        let lock_scheduler = LockScheduler.LockScheduler({
            state = lock_scheduler_state;
            on_change = func({ event: LockEvent; new_tvl: Nat; time: Nat; }){
                yielder.update_tvl({ new_tvl; time; });
                foresight_updater.update_foresights({ time; });
            };
        });

        let duration_calculator = DurationCalculator.PowerScaler({
            nominal_duration = nominal_lock_duration;
        });

        let yes_no_controller = VoteFactory.build_yes_no({
            parameters;
            ballot_register;
            decay_model = Decay.DecayModel(decay);
            lock_info_updater = LockInfoUpdater.LockInfoUpdater({duration_calculator});
        });

        let vote_type_controller = VoteTypeController.VoteTypeController({
            yes_no_controller;
        });

        let queries = Queries.Queries({
            vote_register;
            ballot_register;
            dsn_debt_register = dsn.debt_register;
            clock;
            lock_register;
        });

        Controller.Controller({
            clock;
            vote_register;
            ballot_register;
            lock_scheduler;
            vote_type_controller;
            btc_debt;
            dsn_debt;
            queries;
            minter;
            parameters;
        });
    };

};