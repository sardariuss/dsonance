import Types                  "Types";
import Controller             "Controller";
import ProtocolTimer          "ProtocolTimer";
import Decay                  "duration/Decay";
import DurationCalculator     "duration/DurationCalculator";
import VoteFactory            "votes/VoteFactory";
import VoteTypeController     "votes/VoteTypeController";
import LedgerFacade           "payement/LedgerFacade";
import ParticipationDispenser "ParticipationDispenser";
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

        let { clock_parameters; vote_register; ballot_register; lock_register; deposit; resonance; parameters; provider; admin; minting_info; } = args;
        let { nominal_lock_duration; decay; } = parameters;

        let deposit_ledger = LedgerFacade.LedgerFacade({ deposit with provider; });
        let resonance_ledger = LedgerFacade.LedgerFacade({ resonance with provider; });

        let clock = Clock.Clock(clock_parameters);

        let deposit_debt = DebtProcessor.DebtProcessor({
            deposit with 
            get_debt_info = func (id: UUID) : DebtInfo {
                switch(Map.get(ballot_register.ballots, Map.thash, id)) {
                    case(null) { Debug.trap("Debt not found"); };
                    case(?ballot) {
                        BallotUtils.unwrap_yes_no(ballot).ck_btc;
                    };
                };
            };
            ledger = deposit_ledger;
            on_successful_transfer = null;
        });

        let resonance_debt = DebtProcessor.DebtProcessor({
            resonance with 
            get_debt_info = func (id: UUID) : DebtInfo {
                switch(Map.get(ballot_register.ballots, Map.thash, id)) {
                    case(null) { Debug.trap("Debt not found"); };
                    case(?ballot) {
                        BallotUtils.unwrap_yes_no(ballot).resonance;
                    };
                };
            };
            ledger = resonance_ledger;
            on_successful_transfer = ?(
                func({amount: Nat}) {
                    // Update the total amount minted
                    Timeline.add(minting_info.amount_minted, clock.get_time(), minting_info.amount_minted.current.data + amount);
                }
            );
        });

        let participation_dispenser = ParticipationDispenser.ParticipationDispenser({
            lock_register;
            parameters;
            debt_processor = resonance_debt;
        });

        let duration_calculator = DurationCalculator.PowerScaler({
            nominal_duration = nominal_lock_duration;
        });
        
        let lock_scheduler = LockScheduler.LockScheduler({
            lock_register;
            update_lock_duration = func(ballot: YesNoBallot, time: Time) {
                duration_calculator.update_lock_duration(ballot, ballot.hotness, time);
            };
            about_to_add = func (_: YesNoBallot, time: Time) {
                participation_dispenser.dispense(time);
            };
            about_to_remove = func (ballot: YesNoBallot, time: Time) {
                participation_dispenser.dispense(time);
                
                // Transfer the discernment
                resonance_debt.add_debt({
                    amount = Timeline.current(ballot.rewards).discernment;
                    id = ballot.ballot_id;
                    time;
                });
                
                // Unlock the BTC deposit
                deposit_debt.add_debt({ 
                    amount = Float.fromInt(ballot.amount);
                    id = ballot.ballot_id;
                    time;
                });
            };
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
        });

        Controller.Controller({
            clock;
            vote_register;
            ballot_register;
            lock_scheduler;
            vote_type_controller;
            deposit_debt;
            resonance_debt;
            decay_model;
            participation_dispenser;
            protocol_timer;
            minting_info;
            parameters;
        });
    };

};