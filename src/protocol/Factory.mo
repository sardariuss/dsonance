import Types                  "Types";
import Controller             "Controller";
import Queries                "Queries";
import Decay                  "duration/Decay";
import DurationScaler         "duration/DurationScaler";
import VoteFactory            "votes/VoteFactory";
import VoteTypeController     "votes/VoteTypeController";
import LockInfoUpdater        "locks/LockInfoUpdater";
import LockScheduler          "LockScheduler";
import Clock                  "utils/Clock";
import Timeline               "utils/Timeline"; 
import IterUtils              "utils/Iter";
import MapUtils               "utils/Map";
import ForesightUpdater       "ForesightUpdater";
import Incentives             "votes/Incentives";
import LendingFactory         "lending/LendingFactory";
import LedgerFungible         "ledger/LedgerFungible";
import LedgerAccount          "ledger/LedgerAccount";
import Dex                    "ledger/Dex";
import PriceTracker           "ledger/PriceTracker";
import ParticipationMinter    "ParticipationMinter";

import Debug                  "mo:base/Debug";
import Int                    "mo:base/Int";
import Map                    "mo:map/Map";
import Set                    "mo:map/Set";
import Result                 "mo:base/Result";
import Timer                  "mo:base/Timer";

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
    type Set<K>      = Set.Set<K>;
    type Time        = Int;

    type BuildOutput = {
        controller: Controller.Controller;
        queries: Queries.Queries;
        initialize: () -> async* Result.Result<(), Text>;
    };

    public func build({
        state: State;
        protocol: Principal;
        admin: Principal;
    }) : BuildOutput {

        let { genesis_time; vote_register; ballot_register; lock_scheduler_state; parameters; accounts; lending; collateral_twap_price; participation; } = state;
        let { duration_scaler; twap_config; } = parameters;

        let clock = Clock.Clock(parameters.clock);

        let supply_ledger = LedgerFungible.LedgerFungible(state.supply_ledger);
        let collateral_ledger = LedgerFungible.LedgerFungible(state.collateral_ledger);
        let participation_ledger = LedgerFungible.LedgerFungible(state.participation_ledger);
        
        let participation_account = LedgerAccount.LedgerAccount({
            protocol_account = { owner = protocol; subaccount = null; };
            ledger = participation_ledger;
        });

        let dex = Dex.Dex(state);

        let collateral_price_tracker = PriceTracker.TWAPPriceTracker({
            dex;
            tracked_twap_price = collateral_twap_price;
            twap_config;
            pay_ledger = collateral_ledger;
            receive_ledger = supply_ledger;
            get_current_time = clock.get_time;
        });

        let { supply; supply_registry; borrow_registry; withdrawal_queue; indexer; } = LendingFactory.build({
            lending with
            parameters = parameters.lending;
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
            initial_supply_info = to_supply_info(indexer.get_index());
            get_items = func() : Iter<ForesightUpdater.ForesightItem> {
                // Map the ballots to foresight items
                get_foresight_items(Map.keys(lock_scheduler_state.map), ballot_register.ballots, parameters);
            };
        });

        // Update the foresights when the indexer state is updated
        indexer.add_observer(func(lending_index: Types.LendingIndex) {
            foresight_updater.set_supply_info(to_supply_info(lending_index));
        });
        
        // TODO: the foresight_updater should directly listen to the Indexer updates instead of the LockScheduler
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
                        // @todo: could be done in the controller instead
                        ignore supply_registry.remove_position({
                            id;
                            interest_amount = Int.abs(ballot.foresight.reward);
                        });
                        { ballot; diff = -amount; };
                    };
                };

                // Update the vote TVL
                // @todo: TVL could be computed on query
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

        let duration_scaler_instance = DurationScaler.DurationScaler({
            a = duration_scaler.a;
            b = duration_scaler.b;
        });

        let participation_minter = ParticipationMinter.ParticipationMinter({
            genesis_time;
            parameters = parameters.participation;
            minting_account = participation_account;
            register = participation;
            supply_positions = lending.register.supply_positions;
            borrow_positions = lending.register.borrow_positions;
            lending_index = lending.index;
        });

        let yes_no_controller = VoteFactory.build_yes_no({
            parameters;
            ballot_register;
            decay_model = Decay.DecayModel({ half_life_ns = parameters.ballot_half_life_ns; genesis_time; });
            lock_info_updater = LockInfoUpdater.LockInfoUpdater({duration_scaler = duration_scaler_instance});
        });

        let vote_type_controller = VoteTypeController.VoteTypeController({
            yes_no_controller;
        });

        let controller = Controller.Controller({
            genesis_time;
            clock;
            vote_register;
            ballot_register;
            lock_scheduler;
            vote_type_controller;
            supply;
            supply_registry;
            borrow_registry;
            withdrawal_queue;
            collateral_price_tracker;
            participation_minter;
            parameters;
        });
        let queries = Queries.Queries({
            state;
            clock;
        });

        {
            controller;
            queries;
            initialize = func() : async* Result.Result<(), Text> {
                switch(await* supply_ledger.initialize()) {
                    case(#err(e)) { return #err("Failed to initialize supply ledger: " # e); };
                    case(#ok(_)) {};
                };
                switch(await* collateral_ledger.initialize()) {
                    case(#err(e)) { return #err("Failed to initialize collateral ledger: " # e); };
                    case(#ok(_)) {};
                };
                switch(await* participation_ledger.initialize()) {
                    case(#err(e)) { return #err("Failed to initialize participation ledger: " # e); };
                    case(#ok(_)) {};
                };
                switch(await* collateral_price_tracker.fetch_price()) {
                    case(#err(error)) { return #err("Failed to update collateral price: " # error); };
                    case(#ok(_)) {};
                };
                ignore Timer.recurringTimer<system>(#seconds(parameters.timer_interval_s), func() : async () {
                    await* controller.run();
                });
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

    func get_foresight_items(locked_ballots: Iter<Text>, ballots: Map<UUID, BallotType>, parameters: Types.AgeBonusParameters) : Iter<ForesightUpdater.ForesightItem> {
        IterUtils.map(locked_ballots, func(ballot_id: Text) : ForesightUpdater.ForesightItem {
            let ballot_type = MapUtils.getOrTrap(ballots, Map.thash, ballot_id);
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
                        update_foresight = func(foresight: Types.Foresight) { 
                            b.foresight := foresight;
                        };
                    };
                };
            };
        });
    };

    func to_supply_info(lending_index: Types.LendingIndex) : ForesightUpdater.SupplyInfo {
        {
            accrued_interests = lending_index.accrued_interests.supply;
            interests_rate = lending_index.supply_rate;
            timestamp = lending_index.timestamp;
        };
    };

};