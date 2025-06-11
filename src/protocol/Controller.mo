import Types                   "Types";
import LockScheduler           "LockScheduler";
import Queries                 "Queries";
import MapUtils                "utils/Map";
import Timeline                "utils/Timeline";
import Clock                   "utils/Clock";
import SharedConversions       "shared/SharedConversions";
import BallotUtils             "votes/BallotUtils";
import VoteTypeController      "votes/VoteTypeController";
import IdFormatter             "IdFormatter";
import IterUtils               "utils/Iter";
import ProtocolTimer           "ProtocolTimer";
import Indexer                 "lending/Indexer";
import SupplyRegistry          "lending/SupplyRegistry";
import BorrowRegistry          "lending/BorrowRegistry";
import WithdrawalQueue         "lending/WithdrawalQueue";

import Map                     "mo:map/Map";

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
    type PreviewBallotResult = Types.PreviewBallotResult;
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

    type Iter<T> = Map.Iter<T>;
    type Map<K, V> = Map.Map<K, V>;

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
        indexer: Indexer.Indexer;
        supply_registry: SupplyRegistry.SupplyRegistry;
        borrow_registry: BorrowRegistry.BorrowRegistry;
        withdrawal_queue: WithdrawalQueue.WithdrawalQueue;
        queries: Queries.Queries;
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

        public func preview_ballot(args: PutBallotArgs) : PreviewBallotResult {

            let { id; vote_id; choice_type; caller; from_subaccount; amount; } = args;

            let ballot_id = IdFormatter.format(#VoteId(id));

            let vote_type = switch(Map.get(vote_register.votes, Map.thash, vote_id)){
                case(null) { return #err(#VoteNotFound({vote_id})); };
                case(?v) { v };
            };

            if (amount < parameters.minimum_ballot_amount){
                return #err(#InsufficientAmount({ amount; minimum = parameters.minimum_ballot_amount; }));
            };

            let timestamp = clock.get_time();
            let from = { owner = caller; subaccount = from_subaccount; };

            let { new; previous; } = vote_type_controller.preview_ballot({vote_type; choice_type; args = { args with ballot_id; tx_id = 0; timestamp; from; }});

            // @todo: Refresh the foresight
            //let yes_no_ballot = BallotUtils.unwrap_yes_no(new);
            //Timeline.insert(yes_no_ballot.foresight, timestamp, lock_scheduler.preview_foresight(yes_no_ballot));

            #ok({ new; previous; });
        };

        public func put_ballot(args: PutBallotArgs) : async* PutBallotResult {

            let { id; vote_id; choice_type; caller; from_subaccount; amount; } = args;

            let ballot_id = IdFormatter.format(#BallotId(id));

            let vote_type = switch(Map.get(vote_register.votes, Map.thash, vote_id)){
                case(null) { return #err(#VoteNotFound({vote_id}));  };
                case(?v) { v };
            };

            switch(Map.get(ballot_register.ballots, Map.thash, ballot_id)){
                case(?_) { return #err(#BallotAlreadyExists({ballot_id})); };
                case(null) {};
            };

            if (amount < parameters.minimum_ballot_amount){
                return #err(#InsufficientAmount({ amount; minimum = parameters.minimum_ballot_amount; }));
            };

            let transfer = await* supply_registry.add_position({
                id;
                account = { owner = caller; subaccount = from_subaccount; };
                supplied = amount;
            });

            let tx_id = switch(transfer){
                case(#err(err)) { return #err(#GenericError({ error_code = 0; message = err; })); };
                case(#ok(tx_id)) { tx_id; };
            };

            let timestamp = clock.get_time();
            let from = { owner = caller; subaccount = from_subaccount; };

            let ballot_type = vote_type_controller.put_ballot({vote_type; choice_type; args = { args with ballot_id; tx_id; timestamp; from; }});

            // Update the locks
            lock_scheduler.add(
                BallotUtils.unwrap_lock(ballot_type),
                IterUtils.map<BallotType, Lock>(vote_type_controller.vote_ballots(vote_type), BallotUtils.unwrap_lock),
                timestamp);

            // @todo: this is kind of a hack to have an up-to-date foresight and contribution, should be removed
            //let yes_no_ballot = BallotUtils.unwrap_yes_no(ballot_type);
            //Timeline.insert(yes_no_ballot.foresight, timestamp, lock_scheduler.preview_foresight(yes_no_ballot));

            // Add the ballot to that account
            MapUtils.putInnerSet(ballot_register.by_account, MapUtils.acchash, from, Map.thash, ballot_id);

            // TODO: Ideally it's not the controller's responsibility to share types
            #ok(SharedConversions.shareBallotType(ballot_type));
        };

        public func get_indexer_state() : Types.SIndexerState {
            indexer.get_state();
        };

        public func supply_collateral({
            account: Account;
            amount: Nat;
        }) : async* Result<(), Text> {
            await* borrow_registry.supply_collateral({ account; amount; });
        };

        public func withdraw_collateral({
            account: Account;
            amount: Nat;
        }) : async* Result<(), Text> {
            await* borrow_registry.withdraw_collateral({ account; amount; });
        };

        public func borrow({
            account: Account;
            amount: Nat;
        }) : async* Result<(), Text> {
            await* borrow_registry.borrow({ account; amount; });
        };

        public func repay({
            account: Account;
            repayment: {
                #PARTIAL: Nat;
                #FULL;
            };
        }) : async* Result<(), Text> {
            await* borrow_registry.repay({ account; repayment; });
        };

        // @todo: what to do with the results ?
        public func run() : async* () {
            
            let time = clock.get_time();
            Debug.print("Running controller at time: " # debug_show(time));

            ignore await* borrow_registry.check_all_positions_and_liquidate();
            
            lock_scheduler.try_unlock(time);

            ignore await* withdrawal_queue.process_pending_withdrawals();
        };

        public func get_queries() : Queries.Queries {
            queries;
        };

        public func get_clock() : Clock.Clock {
            clock;
        };

        public func set_timer_interval({ caller: Principal; interval_s: Nat; }) : async* Result<(), Text> {
            await* protocol_timer.set_interval({ caller; interval_s; });
        };

        public func start_timer({ caller: Principal; }) : async* Result<(), Text> {
            await* protocol_timer.start_timer({ caller; fn = run; });
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

    };

};