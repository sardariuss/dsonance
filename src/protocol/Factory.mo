import Types                  "Types";
import Controller             "Controller";
import ProtocolTimer          "ProtocolTimer";
import Decay                  "duration/Decay";
import DurationCalculator     "duration/DurationCalculator";
import VoteFactory            "votes/VoteFactory";
import VoteTypeController     "votes/VoteTypeController";
import LedgerFacade           "payement/LedgerFacade";
import LockScheduler          "LockScheduler";
import Clock                  "utils/Clock";
import HotMap                 "locks/HotMap";
import Timeline               "utils/Timeline";
import DebtProcessor          "DebtProcessor";
import BallotUtils            "votes/BallotUtils";

import Map                    "mo:map/Map";

import Float                  "mo:base/Float";
import Debug                  "mo:base/Debug";

module {

    type State       = Types.State;
    type YesNoBallot = Types.YesNoBallot;
    type UUID        = Types.UUID;
    type DebtInfo    = Types.DebtInfo;

    type Time        = Int;

    public func build(args: State and { provider: Principal; admin: Principal; }) : Controller.Controller {

        let { vote_register; ballot_register; lock_register; btc; dsn; parameters; provider; admin; minting_info; } = args;
        let { nominal_lock_duration; decay; } = parameters;

        let btc_ledger = LedgerFacade.LedgerFacade({ btc with provider; });
        let dsn_ledger = LedgerFacade.LedgerFacade({ dsn with provider; });

        let clock = Clock.Clock(parameters.clock);

        let btc_debt = DebtProcessor.DebtProcessor({
            btc with 
            get_debt_info = func (id: UUID) : DebtInfo {
                switch(Map.get(ballot_register.ballots, Map.thash, id)) {
                    case(null) { Debug.trap("Debt not found"); };
                    case(?ballot) {
                        BallotUtils.unwrap_yes_no(ballot).btc_debt;
                    };
                };
            };
            ledger = btc_ledger;
            on_successful_transfer = null;
        });

        let dsn_debt = DebtProcessor.DebtProcessor({
            dsn with 
            get_debt_info = func (id: UUID) : DebtInfo {
                switch(Map.get(ballot_register.ballots, Map.thash, id)) {
                    case(null) { Debug.trap("Debt not found"); };
                    case(?ballot) {
                        BallotUtils.unwrap_yes_no(ballot).dsn_debt;
                    };
                };
            };
            ledger = dsn_ledger;
            on_successful_transfer = ?(
                func({amount: Nat}) {
                    // Update the total amount minted
                    Timeline.add(minting_info.amount_minted, clock.get_time(), minting_info.amount_minted.current.data + amount);
                }
            );
        });

        let duration_calculator = DurationCalculator.PowerScaler({
            nominal_duration = nominal_lock_duration;
        });
        
        let lock_scheduler = LockScheduler.LockScheduler({
            parameters;
            lock_register;
            update_lock_duration = func(ballot: YesNoBallot, time: Nat) {
                duration_calculator.update_lock_duration(ballot, ballot.hotness, time);
            };
            btc_debt;
            dsn_debt;
        });

        let decay_model = Decay.DecayModel(decay);

        let yes_no_controller = VoteFactory.build_yes_no({
            parameters;
            ballot_register;
            decay_model;
            hot_map = HotMap.HotMap();
        });

        let vote_type_controller = VoteTypeController.VoteTypeController({
            yes_no_controller;
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
            protocol_timer;
            minting_info;
            parameters;
        });
    };

};