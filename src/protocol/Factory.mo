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
import LedgerFungible         "ledger/LedgerFungible";
import Dex                    "ledger/Dex";
import PriceTracker           "ledger/PriceTracker";

import Debug                  "mo:base/Debug";
import Int                    "mo:base/Int";
import Map                    "mo:map/Map";
import Result                 "mo:base/Result";

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

    type BuildOutput = {
        controller: Controller.Controller;
        initialize: () -> async* Result.Result<(), Text>;
    };

    public func build(args: State and { protocol: Principal; admin: Principal; }) : BuildOutput {

        let { vote_register; ballot_register; lock_scheduler_state; parameters; protocol; admin; accounts; lending; collateral_price_in_supply; } = args;
        let { nominal_lock_duration; decay; } = parameters;

        let clock = Clock.Clock(parameters.clock);

        let supply_ledger = LedgerFungible.LedgerFungible(args.supply_ledger);
        let collateral_ledger = LedgerFungible.LedgerFungible(args.collateral_ledger);

        let dex = Dex.Dex(args.dex);

        let collateral_price_tracker = PriceTracker.PriceTracker({
            dex;
            tracked_price = collateral_price_in_supply;
            pay_ledger = collateral_ledger;
            receive_ledger = supply_ledger;
        });

        let { supply_registry; borrow_registry; withdrawal_queue; indexer; } = LendingFactory.build({
            lending with
            collateral_price_tracker;
            protocol_info = {
                accounts with
                principal = protocol;
            };
            admin;
            supply_ledger;
            collateral_ledger;
            dex;
            clock;
        });

        let foresight_updater = ForesightUpdater.ForesightUpdater({
            initial_supply_info = to_supply_info(indexer.get_state());
            get_items = func() : Iter<ForesightUpdater.ForesightItem> {
                // Map the ballots to foresight items
                map_ballots_to_foresight_items(ballot_register.ballots, parameters);
            };
        });

        // Update the foresights when the indexer state is updated
        indexer.add_observer(func(indexer_state: Types.SIndexerState) {
            foresight_updater.set_supply_info(to_supply_info(indexer_state));
        });
        
        // @int: the foresight_updater should directly listen to the Indexer updates instead of the LockScheduler
        let lock_scheduler = LockScheduler.LockScheduler({
            state = lock_scheduler_state;
            before_change = func({ time: Nat; state: LockState; }){};
            after_change = func({ time: Nat; event: LockEvent; state: LockState; }){
                
                // Update the ballots foresights
                foresight_updater.update_foresights();

                let { ballot; diff; } = switch(event){
                    case(#LOCK_ADDED({id; amount;})){
                        { ballot = get_ballot(ballot_register.ballots, id); diff = amount; };
                    };
                    case(#LOCK_REMOVED({id; amount;})){

                        let ballot = get_ballot(ballot_register.ballots, id);
                        
                        // TODO: what if it returns an error?
                        ignore supply_registry.remove_position({
                            id;
                            share = Timeline.current(ballot.foresight).share;
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
            clock;
        });

        let protocol_timer = ProtocolTimer.ProtocolTimer({
            admin;
            parameters = parameters.timer;
        });

        {
            controller = Controller.Controller({
                clock;
                vote_register;
                ballot_register;
                lock_scheduler;
                vote_type_controller;
                indexer;
                supply_registry;
                borrow_registry;
                withdrawal_queue;
                collateral_price_tracker;
                queries;
                protocol_timer;
                parameters;
            });
            initialize = func() : async* Result.Result<(), Text> {
                switch(await* supply_ledger.initialize()) {
                    case(#err(e)) { return #err("Failed to initialize supply ledger: " # e); };
                    case(#ok(_)) {};
                };
                switch(await* collateral_ledger.initialize()) {
                    case(#err(e)) { return #err("Failed to initialize collateral ledger: " # e); };
                    case(#ok(_)) {};
                };
                switch(await* collateral_price_tracker.fetch_price()) {
                    case(#err(error)) { return #err("Failed to update collateral price: " # error); };
                    case(#ok(_)) {};
                };
                #ok;
            };
        };
    };

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

    // @todo: could return only the items which release_date is in the future, it would avoid to do it in the ForesightUpdater
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

    func to_supply_info(indexer_state: Types.SIndexerState) : ForesightUpdater.SupplyInfo {
        {
            accrued_interests = indexer_state.accrued_interests.supply;
            interests_rate = indexer_state.supply_rate;
            last_update_timestamp = indexer_state.last_update_timestamp;
        };
    };

};