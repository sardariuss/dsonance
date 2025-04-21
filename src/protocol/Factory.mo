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
import LockScheduler          "LockScheduler";
import Clock                  "utils/Clock";
import Timeline               "utils/Timeline";
import DebtProcessor          "DebtProcessor";
import TokenMinter            "TokenMinter"; 
import IterUtils              "utils/Iter";
import ForesightUpdater       "ForesightUpdater";
import BallotUtils            "votes/BallotUtils";
import Incentives             "votes/Incentives";
import ProtocolTimer          "ProtocolTimer";

import Debug                  "mo:base/Debug";
import Int                    "mo:base/Int";
import Float                  "mo:base/Float";
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
    type VoteType    = Types.VoteType;
    type LockState   = Types.LockState; 
    
    type Iter<T>     = Map.Iter<T>;
    type Map<K, V>   = Map.Map<K, V>;
    type Time        = Int;

    public func build(args: State and { provider: Principal; admin: Principal; }) : Controller.Controller {

        let { vote_register; ballot_register; lock_scheduler_state; btc; dsn; parameters; provider; yield_state; admin; } = args;
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
            before_change = func({ time: Nat; state: LockState; }){
                
                // Mint the tokens until time
                minter.mint({
                    time;
                    locked_ballots = map_locks_to_pair(state.locks, ballot_register.ballots, vote_register.votes);
                    tvl = state.tvl;
                });
            };
            after_change = func({ time: Nat; event: LockEvent; state: LockState; }){
                
                // Update the overall tvl and yield
                yielder.update_tvl({ new_tvl = state.tvl; time; });
                
                // Update the ballots foresights
                foresight_updater.update_foresights({ time; });

                let { ballot; diff; } = switch(event){
                    case(#LOCK_ADDED({id; amount;})){
                        { ballot = get_ballot(ballot_register.ballots, id); diff = amount; };
                    };
                    case(#LOCK_REMOVED({id; amount;})){
                        let ballot = get_ballot(ballot_register.ballots, id);
                        
                        // Initiate the transfer of the locked BTC and yield
                        btc_debt.increase_debt({ 
                            id;
                            account = ballot.from;
                            amount = Float.fromInt(ballot.amount + Timeline.current(ballot.foresight).reward);
                            pending = 0.0;
                            time;
                        });
                        { ballot; diff = -amount; };
                    };
                };

                // Update the vote TVL
                let vote = get_vote(vote_register.votes, ballot.vote_id);
                vote.tvl := do {
                    let new_tvl : Int = vote.tvl + diff;
                    if (new_tvl < 0) {
                        Debug.trap("TVL cannot be negative");
                    };
                    Int.abs(new_tvl);
                };
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
        });

        let protocol_timer = ProtocolTimer.ProtocolTimer({
            admin;
            parameters = parameters.timer;
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
            protocol_timer;
            minter;
            parameters;
        });
    };

    // TODO: remove duplicate (see Controller)

    func get_ballot(ballots: Map<UUID, BallotType>, id: UUID) : YesNoBallot {
        switch(Map.get(ballots, Map.thash, id)) {
            case(null) { Debug.trap("Ballot " #  debug_show(id) # " not found"); };
            case(?#YES_NO(ballot)) {
                ballot;
            };
        };
    };

    func get_vote(votes: Map<UUID, VoteType>, id: UUID) : YesNoVote {
        switch(Map.get(votes, Map.thash, id)) {
            case(null) { Debug.trap("Vote " #  debug_show(id) # " not found"); };
            case(?#YES_NO(vote)) {
                vote;
            };
        };
    };

    func map_locks_to_pair(locks: Iter<Lock>, ballots: Map<UUID, BallotType>, votes: Map<UUID, VoteType>) : Iter<(YesNoBallot, YesNoVote)> {
        IterUtils.map<Lock, (YesNoBallot, YesNoVote)>(locks, func(lock: Lock) : (YesNoBallot, YesNoVote) {
            let ballot = get_ballot(ballots, lock.id);
            let vote = get_vote(votes, ballot.vote_id);
            (ballot, vote);
        });
    };

};