import Types                  "Types";
import Controller             "Controller";
import Queries                "Queries";
import Decay                  "duration/Decay";
import DurationCalculator     "duration/DurationCalculator";
import VoteFactory            "votes/VoteFactory";
import VoteTypeController     "votes/VoteTypeController";
import LockInfoUpdater        "locks/LockInfoUpdater";
import LockScheduler          "LockScheduler";
import Clock                  "utils/Clock";
import Timeline               "utils/Timeline"; 
import IterUtils              "utils/Iter";
import ForesightUpdater       "ForesightUpdater";
import Incentives             "votes/Incentives";
import ProtocolTimer          "ProtocolTimer";
import LendingFactory         "lending/LendingFactory";
import ActorInterface         "ActorInterface";

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

    public func build(args: State and { protocol: Principal; admin: Principal; }) : Controller.Controller {

        let { supply_ledger; collateral_ledger; dex; vote_register; ballot_register; lock_scheduler_state; parameters; protocol; admin; lending; } = args;
        let { nominal_lock_duration; decay; } = parameters;

        let clock = Clock.Clock(parameters.clock);

        let { supply_registry } = LendingFactory.build({
            lending with
            protocol_account = { owner = protocol; subaccount = null; };
            admin;
            supply_ledger = ActorInterface.wrapLedgerFungible(supply_ledger);
            collateral_ledger = ActorInterface.wrapLedgerFungible(collateral_ledger);
            dex = ActorInterface.wrapDex(dex);
            clock;
        });

        // @int: foresight_updater.update_foresights should also be called when the yield is updated
        // so on borrow, withdraw, etc.
        let foresight_updater = ForesightUpdater.ForesightUpdater({
            get_yield = func () : { earned: Float; apr: Float; time_last_update: Nat; } {
                // @int: use Indexer instead
                {
                    earned = 0.0;
                    apr = 0.0;
                    time_last_update = 0;
                }
            };
        });
        
        // @int: the foresight_updater should directly listen to the Indexer updates instead of the LockScheduler
        let lock_scheduler = LockScheduler.LockScheduler({
            state = lock_scheduler_state;
            before_change = func({ time: Nat; state: LockState; }){};
            after_change = func({ time: Nat; event: LockEvent; state: LockState; }){
                
                // Update the ballots foresights
                foresight_updater.update_foresights(map_ballots_to_foresight_items(ballot_register.ballots, parameters));

                let { ballot; diff; } = switch(event){
                    case(#LOCK_ADDED({id; amount;})){
                        { ballot = get_ballot(ballot_register.ballots, id); diff = amount; };
                    };
                    case(#LOCK_REMOVED({id; amount;})){
                        
                        let ballot = get_ballot(ballot_register.ballots, id);
                        let ballot_interest = Timeline.current(ballot.foresight).reward;

                        // Update the ballots foresights
                        foresight_updater.update_foresights(map_ballots_to_foresight_items(ballot_register.ballots, parameters));
                        
                        // @todo: solve this
                        //supply_registry.remove_position({
                            //id;
                            //share = 0.0; // @todo
                        //});
                        { ballot; diff = -amount; };
                    };
                };

                // Update the vote TVL
                // @int: this shall still be done
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
            supply_registry;
            queries;
            protocol_timer;
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

    func map_ballots_to_foresight_items(ballots: Map<UUID, BallotType>, parameters: Types.AgeBonusParameters) : Iter<ForesightUpdater.ForesightItem> {
        IterUtils.map(Map.vals(ballots), func(ballot_type: BallotType) : ForesightUpdater.ForesightItem {
            switch(ballot_type){
                case(#YES_NO(b)) {     
                    let release_date = switch(b.lock){
                        case(null) { Debug.trap("The ballot does not have a lock"); };
                        case(?lock) { lock.release_date; };
                    };
                    let discernment = Incentives.compute_discernment({
                        dissent = b.dissent;
                        consent = Timeline.current(b.consent);
                        lock_duration = release_date - b.timestamp;
                        parameters;
                    });
                    {
                        timestamp = b.timestamp;
                        amount = b.amount;
                        release_date;
                        discernment;
                        consent = Timeline.current(b.consent);
                        update_foresight = func(foresight: Types.Foresight, time: Nat) { 
                            Timeline.insert(b.foresight, time, foresight);
                        };
                    };
                };
            };
        });
    };

};