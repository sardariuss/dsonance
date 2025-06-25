import Types                   "Types";
import LockScheduler           "LockScheduler";
import MapUtils                "utils/Map";
import Timeline                "utils/Timeline";
import Clock                   "utils/Clock";
import SharedConversions       "shared/SharedConversions";
import BallotUtils             "votes/BallotUtils";
import VoteTypeController      "votes/VoteTypeController";
import IdFormatter             "IdFormatter";
import IterUtils               "utils/Iter";
import ProtocolTimer           "ProtocolTimer";
import LendingTypes            "lending/Types";
import SupplyRegistry          "lending/SupplyRegistry";
import BorrowRegistry          "lending/BorrowRegistry";
import WithdrawalQueue         "lending/WithdrawalQueue";
import PriceTracker            "ledger/PriceTracker";
import ForesightUpdater        "ForesightUpdater";
import Incentives              "votes/Incentives";

import Map                     "mo:map/Map";
import Set                     "mo:map/Set";

import Int                     "mo:base/Int";
import Float                   "mo:base/Float";
import Debug                   "mo:base/Debug";
import Result                  "mo:base/Result";

module {

    type Time = Int;
    type VoteRegister = Types.VoteRegister;
    type VoteType = Types.VoteType;
    type BallotType = Types.BallotType;
    type PutBallotResult = Types.PutBallotResult;
    type ChoiceType = Types.ChoiceType;
    type Account = Types.Account;
    type TimedData<T> = Timeline.TimedData<T>;
    type UUID = Types.UUID;
    type SNewVoteResult = Types.SNewVoteResult;
    type BallotRegister = Types.BallotRegister;
    type TimerParameters = Types.TimerParameters;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type ProtocolParameters = Types.ProtocolParameters;
    type Timeline<T> = Types.Timeline<T>;
    type ProtocolInfo = Types.ProtocolInfo;
    type YesNoBallot = Types.YesNoBallot;
    type YesNoVote = Types.YesNoVote;
    type Lock = Types.Lock;
    type Duration = Types.Duration;
    type YieldState = Types.YieldState;
    type PutBallotError = Types.PutBallotError;
    type LoanPosition = LendingTypes.LoanPosition;
    type BorrowOperation = LendingTypes.BorrowOperation;
    type BorrowOperationArgs = LendingTypes.BorrowOperationArgs;

    type Iter<T> = Map.Iter<T>;
    type Map<K, V> = Map.Map<K, V>;
    type Set<T> = Set.Set<T>;

    type WeightParams = {
        ballot: BallotType;
        update_ballot: (BallotType) -> ();
        weight: Float;
    };

    public type NewVoteArgs = {
        id: UUID;
        origin: Principal;
        type_enum: Types.VoteTypeEnum;
        account: Account;
    };

    public type PutBallotArgs = {
        id: UUID;
        vote_id: UUID;
        choice_type: ChoiceType;
        caller: Principal;
        from_subaccount: ?Blob;
        amount: Nat;
    };

    public class Controller({
        clock: Clock.Clock;
        vote_register: VoteRegister;
        ballot_register: BallotRegister;
        lock_scheduler: LockScheduler.LockScheduler;
        vote_type_controller: VoteTypeController.VoteTypeController;
        supply_registry: SupplyRegistry.SupplyRegistry;
        borrow_registry: BorrowRegistry.BorrowRegistry;
        withdrawal_queue: WithdrawalQueue.WithdrawalQueue;
        collateral_price_tracker: PriceTracker.PriceTracker;
        protocol_timer: ProtocolTimer.ProtocolTimer;
        parameters: ProtocolParameters;
    }){

        public func new_vote(args: NewVoteArgs) : async* SNewVoteResult {

            let { type_enum; origin; id; account; } = args;

            let vote_id = IdFormatter.format(#VoteId(id));

            if (Map.has(vote_register.votes, Map.thash, vote_id)){
                return #err(#VoteAlreadyExists({vote_id}));
            };

            // Add the vote
            let vote = vote_type_controller.new_vote({
                vote_id;
                tx_id = 0; // @todo: for now everyone can create a vote without a transfer
                vote_type_enum = type_enum;
                date = clock.get_time();
                origin;
                author = account;
            });
            Map.set(vote_register.votes, Map.thash, vote_id, vote);

            // Update the by_origin and by_author maps
            MapUtils.putInnerSet(vote_register.by_origin, Map.phash, origin, Map.thash, vote_id);
            MapUtils.putInnerSet(vote_register.by_author, MapUtils.acchash, account, Map.thash, vote_id);
            
            // TODO: ideally it's not the controller's responsibility to share types
            #ok(SharedConversions.shareVoteType(vote));
        };

        // This function is made to allow the frontend to preview the result of put_ballot
        // TODO: ideally one should have a true preview function that does not mutate the state
        public func put_ballot_for_free(args: PutBallotArgs) : PutBallotResult {

            let { ballot_id; vote_type; } = switch(process_ballot_input(args)){
                case(#err(err)) { return #err(err); };
                case(#ok(input)) { input; };
            };

            let preview_result = supply_registry.add_position_without_transfer({
                id = ballot_id;
                account = { owner = args.caller; subaccount = args.from_subaccount; };
                supplied = args.amount;
            });

            let tx_id = switch(preview_result){
                case(#err(err)) { return #err(#GenericError({ error_code = 0; message = err; })); };
                case(#ok(tx_id)) { tx_id; };
            };

            perform_put_ballot({
                args;
                vote_type;
                ballot_id;
                tx_id;
            });
        };

        public func put_ballot(args: PutBallotArgs) : async* PutBallotResult {

            let { ballot_id; vote_type; } = switch(process_ballot_input(args)){
                case(#err(err)) { return #err(err); };
                case(#ok(input)) { input; };
            };

            let transfer = await* supply_registry.add_position({
                id = ballot_id;
                account = { owner = args.caller; subaccount = args.from_subaccount; };
                supplied = args.amount;
            });

            let tx_id = switch(transfer){
                case(#err(err)) { return #err(#GenericError({ error_code = 0; message = err; })); };
                case(#ok(tx_id)) { tx_id; };
            };

            perform_put_ballot({
                args;
                vote_type;
                ballot_id;
                tx_id;
            });
        };

        public func run_borrow_operation(args: BorrowOperationArgs) : async* Result<BorrowOperation, Text> {
            await* borrow_registry.run_operation(args);
        };

        public func run_borrow_operation_for_free(args: BorrowOperationArgs) : Result<BorrowOperation, Text> {
            borrow_registry.run_operation_for_free(args);
        };

        public func get_loan_position(account: Account) : LoanPosition {
            borrow_registry.get_loan_position(account);
        };

        public func run() : async* Result<(), Text> {
            
            let time = clock.get_time();
            Debug.print("Running controller at time: " # debug_show(time));

            switch(await* collateral_price_tracker.fetch_price()){
                case(#err(error)) { return #err("Failed to update collateral price: " # error); };
                case(#ok(_)) {};
            };

            switch(await* borrow_registry.check_all_positions_and_liquidate()){
                case(#err(error)) { return #err("Failed to check positions and liquidate: " # error); };
                case(#ok(_)) {};
            };
            
            ignore lock_scheduler.try_unlock(time);

            switch(await* withdrawal_queue.process_pending_withdrawals()){
                case(#err(error)) { return #err("Failed to process pending withdrawals: " # error); };
                case(#ok(_)) {};
            };

            #ok;
        };

        public func get_clock() : Clock.Clock {
            clock;
        };

        public func set_timer_interval({ caller: Principal; interval_s: Nat; }) : async* Result<(), Text> {
            await* protocol_timer.set_interval({ caller; interval_s; });
        };

        public func start_timer({ caller: Principal; }) : async* Result<(), Text> {
            await* protocol_timer.start_timer({ caller; fn = func() : async*() { ignore (await* run()); }});
        };

        public func stop_timer({ caller: Principal }) : Result<(), Text> {
            protocol_timer.stop_timer({ caller });
        };

        public func get_parameters() : ProtocolParameters {
            parameters;
        };

        public func get_info() : ProtocolInfo {
            {
                current_time = clock.get_time();
                last_run = 0; // @todo: use minter instead
                btc_locked = Timeline.initialize<Nat>(0, 0); // @todo
            };
        };

        type ProcessedBallotInput = {
            ballot_id: Text;
            vote_type: VoteType;
        };

        func process_ballot_input(args: PutBallotArgs) : Result<ProcessedBallotInput, PutBallotError> {
            
            let { id; vote_id; amount; } = args;

            let ballot_id = IdFormatter.format(#BallotId(id));

            let vote_type = switch(Map.get(vote_register.votes, Map.thash, vote_id)){
                case(null) return #err(#VoteNotFound({ vote_id }));
                case(?v) v;
            };

            switch(Map.get(ballot_register.ballots, Map.thash, ballot_id)){
                case(?_) return #err(#BallotAlreadyExists({ ballot_id }));
                case(null) {};
            };

            if (amount < parameters.minimum_ballot_amount){
                return #err(#InsufficientAmount({ amount; minimum = parameters.minimum_ballot_amount }));
            };

            #ok({
                ballot_id;
                vote_type;
            });
        };

        func perform_put_ballot({
            args: PutBallotArgs;
            vote_type: VoteType;
            ballot_id: Text;
            tx_id: Nat;
        }): PutBallotResult {

            let timestamp = clock.get_time();
            
            let from = { owner = args.caller; subaccount = args.from_subaccount };

            let ballot_type = vote_type_controller.put_ballot({
                vote_type;
                choice_type = args.choice_type;
                args = { args with ballot_id; tx_id; timestamp; from };
            });

            //lock_scheduler.try_unlock(timestamp);

            lock_scheduler.add(
                BallotUtils.unwrap_lock(ballot_type),
                IterUtils.map<BallotType, Lock>(
                    vote_type_controller.vote_ballots(vote_type),
                    BallotUtils.unwrap_lock
                ),
                timestamp
            );

            MapUtils.putInnerSet(ballot_register.by_account, MapUtils.acchash, from, Map.thash, ballot_id);

            #ok(SharedConversions.shareBallotType(ballot_type))
        };

        func map_ballots_to_foresight_items(ballot_ids: Set<UUID>, parameters: Types.AgeBonusParameters) : Iter<ForesightUpdater.ForesightItem> {

            IterUtils.map(Set.keys(ballot_ids), func(ballot_id: UUID) : ForesightUpdater.ForesightItem {
                let b = switch(Map.get(ballot_register.ballots, Map.thash, ballot_id)){
                    case(null) { Debug.trap("Ballot " #  debug_show(ballot_id) # " not found"); };
                    case(?#YES_NO(ballot)) { ballot; };
                };
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
            });
        };

    };

};