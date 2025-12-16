import Types                  "Types";
import Controller             "Controller";
import Queries                "Queries";
import Miner                  "Miner";
import Decay                  "duration/Decay";
import DurationScaler         "duration/DurationScaler";
import PoolFactory            "pools/PoolFactory";
import PoolTypeController     "pools/PoolTypeController";
import LockInfoUpdater        "locks/LockInfoUpdater";
import LockScheduler          "LockScheduler";
import Clock                  "utils/Clock";
import IterUtils              "utils/Iter";
import MapUtils               "utils/Map";
import UUID                   "utils/Uuid";
import ForesightUpdater       "ForesightUpdater";
import LendingFactory         "lending/LendingFactory";
import LedgerFungible         "ledger/LedgerFungible";
import LedgerAccount          "ledger/LedgerAccount";
import Dex                    "ledger/Dex";
import PriceTracker           "ledger/PriceTracker";

import Debug                  "mo:base/Debug";
import Int                    "mo:base/Int";
import Map                    "mo:map/Map";
import Set                    "mo:map/Set";
import Result                 "mo:base/Result";
import Timer                  "mo:base/Timer";

module {

    type State       = Types.State;
    type YesNoPosition = Types.YesNoPosition;
    type YesNoPool   = Types.YesNoPool;
    type Lock        = Types.Lock; 
    type UUID        = Types.UUID;
    type DebtInfo    = Types.DebtInfo;
    type LockEvent   = Types.LockEvent;
    type PositionType  = Types.PositionType;
    type PoolType    = Types.PoolType;
    
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

        let { 
            genesis_time; 
            pool_register; 
            position_register; 
            limit_order_register;
            lock_scheduler_state; 
            parameters; 
            accounts; 
            lending; 
            collateral_twap_price; 
            mining; 
        } = state;
        let { duration_scaler; twap_config; } = parameters;

        let clock = Clock.Clock(parameters.clock);

        let uuid = UUID.UUIDv7(UUID.PRNG(clock.get_time()));

        let supply_ledger = LedgerFungible.LedgerFungible(state.supply_ledger);
        let collateral_ledger = LedgerFungible.LedgerFungible(state.collateral_ledger);
        let participation_ledger = LedgerFungible.LedgerFungible(state.participation_ledger);
        
        let participation_account = LedgerAccount.LedgerAccount({
            protocol_account = { owner = protocol; subaccount = null; };
            ledger = participation_ledger;
        });

        let dex = Dex.Dex(state);

        let collateral_price_tracker = PriceTracker.TWAPPriceTracker({
            price_source = #Xrc(state.xrc);
            tracked_twap_price = collateral_twap_price;
            twap_config;
            pay_ledger = collateral_ledger;
            receive_ledger = supply_ledger;
            get_current_time = clock.get_time;
        });

        let collateral_usd_price_tracker = PriceTracker.SpotUsdPriceTracker({
            xrc = state.xrc;
            ledger = collateral_ledger;
        });

        let supply_usd_price_tracker = PriceTracker.SpotUsdPriceTracker({
            xrc = state.xrc;
            ledger = supply_ledger;
        });

        let { supply; supply_registry; redistribution_hub; borrow_registry; withdrawal_queue; } = LendingFactory.build({
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
        });

        let foresight_updater = ForesightUpdater.ForesightUpdater({
            redistribution_hub;
            get_items = func() : Iter<ForesightUpdater.ForesightItem> {
                // Map the positions to foresight items
                get_foresight_items(Map.keys(lock_scheduler_state.map), position_register.positions);
            };
        });
        
        let lock_scheduler = LockScheduler.LockScheduler({
            state = lock_scheduler_state;
        });

        let duration_scaler_instance = DurationScaler.DurationScaler({
            a = duration_scaler.a;
            b = duration_scaler.b;
        });

        let miner = Miner.Miner({
            genesis_time;
            parameters = parameters.mining;
            minting_account = participation_account;
            register = mining;
            redistribution_positions = lending.register.redistribution_positions;
            borrow_positions = lending.register.borrow_positions;
            lending_index = lending.index;
        });

        let yes_no_controller = PoolFactory.build_yes_no({
            parameters;
            position_register;
            limit_order_register;
            decay_model = Decay.DecayModel({ half_life_ns = parameters.position_half_life_ns; genesis_time; });
            lock_info_updater = LockInfoUpdater.LockInfoUpdater({duration_scaler = duration_scaler_instance});
            uuid;
        });

        let pool_type_controller = PoolTypeController.PoolTypeController({
            yes_no_controller;
        });

        let controller = Controller.Controller({
            genesis_time;
            clock;
            pool_register;
            position_register;
            lock_scheduler;
            pool_type_controller;
            supply;
            supply_registry;
            redistribution_hub;
            borrow_registry;
            withdrawal_queue;
            collateral_price_tracker;
            collateral_usd_price_tracker;
            supply_usd_price_tracker;
            miner;
            parameters;
            foresight_updater;
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
                switch(await* collateral_usd_price_tracker.fetch_price()) {
                    case(#err(error)) { return #err("Failed to fetch collateral USD price: " # error); };
                    case(#ok(_)) {};
                };
                switch(await* supply_usd_price_tracker.fetch_price()) {
                    case(#err(error)) { return #err("Failed to fetch supply USD price: " # error); };
                    case(#ok(_)) {};
                };
                ignore Timer.recurringTimer<system>(#seconds(parameters.timer_interval_s), func() : async () {
                    await* controller.run();
                });
                #ok;
            };
        };
    };

    func get_foresight_items(locked_positions: Iter<Text>, positions: Map<UUID, PositionType>) : Iter<ForesightUpdater.ForesightItem> {
        IterUtils.map(locked_positions, func(position_id: Text) : ForesightUpdater.ForesightItem {
            let position_type = MapUtils.getOrTrap(positions, Map.thash, position_id);
            switch(position_type){
                case(#YES_NO(b)) {     
                    let release_date = switch(b.lock){
                        case(null) { Debug.trap("The position does not have a lock"); };
                        case(?lock) { lock.release_date; };
                    };
                    {
                        timestamp = b.timestamp;
                        amount = b.amount;
                        release_date;
                        discernment = b.dissent * b.consent;
                        consent = b.consent;
                        update_foresight = func(foresight: Types.Foresight) { 
                            b.foresight := foresight;
                        };
                    };
                };
            };
        });
    };

};