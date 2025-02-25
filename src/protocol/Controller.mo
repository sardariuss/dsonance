import Types                   "Types";
import DebtProcessor           "DebtProcessor";
import ProtocolTimer           "ProtocolTimer";
import LockScheduler           "LockScheduler";
import MapUtils                "utils/Map";
import Timeline                "utils/Timeline";
import Clock                   "utils/Clock";
import SharedConversions       "shared/SharedConversions";
import BallotUtils             "votes/BallotUtils";
import VoteTypeController      "votes/VoteTypeController";


import Map                     "mo:map/Map";
import Set                     "mo:map/Set";

import Int                     "mo:base/Int";
import Option                  "mo:base/Option";
import Float                   "mo:base/Float";
import Debug                   "mo:base/Debug";
import Buffer                  "mo:base/Buffer";
import Iter                    "mo:base/Iter";
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
    type Iter<T> = Iter.Iter<T>;
    type ProtocolParameters = Types.ProtocolParameters;
    type MintingInfo = Types.MintingInfo;
    type Timeline<T> = Types.Timeline<T>;
    type ProtocolInfo = Types.ProtocolInfo;

    type WeightParams = {
        ballot: BallotType;
        update_ballot: (BallotType) -> ();
        weight: Float;
    };

    public type NewVoteArgs = {
        vote_id: UUID;
        origin: Principal;
        type_enum: Types.VoteTypeEnum;
        account: Account;
    };

    public type PutBallotArgs = {
        vote_id: UUID;
        ballot_id: UUID;
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
        btc_debt: DebtProcessor.DebtProcessor;
        dsn_debt: DebtProcessor.DebtProcessor;
        protocol_timer: ProtocolTimer.ProtocolTimer;
        minting_info: MintingInfo;
        parameters: ProtocolParameters;
    }){

        public func new_vote(args: NewVoteArgs) : async* SNewVoteResult {

            let { type_enum; origin; vote_id; account; } = args;

            if (Map.has(vote_register.votes, Map.thash, vote_id)){
                return #err(#VoteAlreadyExists({vote_id}));
            };

            // TODO: the fee should be burnt
            let transfer = await* dsn_debt.get_ledger().transfer_from({
                from = account;
                amount = parameters.opening_vote_fee;
            });

            let tx_id = switch(transfer){
                case(#err(err)) { return #err(err); };
                case(#ok(tx_id)) { tx_id; };
            };

            // Add the vote
            let vote = vote_type_controller.new_vote({
                vote_id;
                tx_id;
                vote_type_enum = type_enum;
                date = clock.get_time();
                origin;
            });
            Map.set(vote_register.votes, Map.thash, vote_id, vote);

            // Update the by_origin map
            let by_origin = Option.get(Map.get(vote_register.by_origin, Map.phash, origin), Set.new<UUID>());
            Set.add(by_origin, Set.thash, vote_id);
            Map.set(vote_register.by_origin, Map.phash, origin, by_origin);

            // TODO: ideally it's not the controller's responsibility to share types
            #ok(SharedConversions.shareVoteType(vote));
        };

        public func preview_ballot(args: PutBallotArgs) : PreviewBallotResult {

            let { vote_id; choice_type; caller; from_subaccount; amount; } = args;

            let vote_type = switch(Map.get(vote_register.votes, Map.thash, vote_id)){
                case(null) { return #err(#VoteNotFound({vote_id})); };
                case(?v) { v };
            };

            if (amount < parameters.minimum_ballot_amount){
                return #err(#InsufficientAmount({ amount; minimum = parameters.minimum_ballot_amount; }));
            };

            let timestamp = clock.get_time();
            let from = { owner = caller; subaccount = from_subaccount; };

            let ballot = vote_type_controller.preview_ballot({vote_type; choice_type; args = { args with tx_id = 0; timestamp; from; }});

            let yes_no_ballot = BallotUtils.unwrap_yes_no(ballot);

            lock_scheduler.refresh_lock_duration(yes_no_ballot, timestamp);

            Timeline.add(yes_no_ballot.foresight, timestamp, lock_scheduler.preview_foresight(yes_no_ballot));
            Timeline.add(yes_no_ballot.contribution, timestamp, lock_scheduler.preview_contribution(yes_no_ballot));

            #ok(ballot);
        };

        public func put_ballot(args: PutBallotArgs) : async* PutBallotResult {

            let { vote_id; ballot_id; choice_type; caller; from_subaccount; amount; } = args;

            let vote_type = switch(Map.get(vote_register.votes, Map.thash, vote_id)){
                case(null) { return #err(#VoteNotFound({vote_id}));  };
                case(?v) { v };
            };

            switch(find_ballot(ballot_id)){
                case(?_) { return #err(#BallotAlreadyExists({ballot_id})); };
                case(null) {};
            };

            if (amount < parameters.minimum_ballot_amount){
                return #err(#InsufficientAmount({ amount; minimum = parameters.minimum_ballot_amount; }));
            };

            let transfer = await* btc_debt.get_ledger().transfer_from({
                from = { owner = caller; subaccount = from_subaccount; };
                amount;
            });

            let tx_id = switch(transfer){
                case(#err(err)) { return #err(err); };
                case(#ok(tx_id)) { tx_id; };
            };

            let timestamp = clock.get_time();
            let from = { owner = caller; subaccount = from_subaccount; };

            let ballot_type = vote_type_controller.put_ballot({vote_type; choice_type; args = { args with tx_id; timestamp; from; }});

            let yes_no_ballot = BallotUtils.unwrap_yes_no(ballot_type);

            // Update the locks
            // TODO: fix the following limitation
            // Watchout, the new ballot shall be added first, otherwise the update will trap
            lock_scheduler.add(yes_no_ballot, timestamp);
            for (ballot in vote_type_controller.vote_ballots(vote_type)){
                lock_scheduler.update(BallotUtils.unwrap_yes_no(ballot), timestamp);
            };

            // TODO: this is kind of a hack to have an up-to-date foresight and contribution, should be removed
            Timeline.add(yes_no_ballot.foresight, timestamp, lock_scheduler.preview_foresight(yes_no_ballot));
            Timeline.add(yes_no_ballot.contribution, timestamp, lock_scheduler.preview_contribution(yes_no_ballot));

            // Add the ballot to that account
            MapUtils.putInnerSet(ballot_register.by_account, MapUtils.acchash, from, Map.thash, ballot_id);

            // TODO: Ideally it's not the controller's responsibility to share types
            #ok(SharedConversions.shareBallotType(ballot_type));
        };

        public func get_ballots(account: Account) : [BallotType] {
            let buffer = Buffer.Buffer<BallotType>(0);
            Option.iterate(Map.get(ballot_register.by_account, MapUtils.acchash, account), func(ids: Set.Set<UUID>) {
                for (id in Set.keys(ids)) {
                    Option.iterate(Map.get(ballot_register.ballots, Map.thash, id), func(ballot_type: BallotType) {
                        buffer.add(ballot_type);
                    });
                };
            }); 
            Buffer.toArray(buffer);
        };

        public func get_vote_ballots(vote_id: UUID) : [BallotType] {
            let vote = switch(Map.get(vote_register.votes, Map.thash, vote_id)){
                case(null) { return []; };
                case(?v) { v };
            };
            let buffer = Buffer.Buffer<BallotType>(0);
            for (ballot in vote_type_controller.vote_ballots(vote)){
                buffer.add(ballot);
            };
            Buffer.toArray(buffer);
        };

        public func run() : async* () {
            let time = clock.get_time();
            Debug.print("Running controller at time: " # debug_show(time));
            lock_scheduler.try_unlock(time);

            let transfers = Buffer.Buffer<async* ()>(3);

            transfers.add(btc_debt.transfer_owed());
            transfers.add(dsn_debt.transfer_owed());

            for (call in transfers.vals()){
                await* call;
            };
        };

        public func get_votes({origin: Principal; filter_ids: ?[UUID]}) : [VoteType] {
            
            let vote_ids = Option.get(Map.get(vote_register.by_origin, Map.phash, origin), Set.new<UUID>());
            let filter = Option.map(filter_ids, func(ids: [UUID]) : Set.Set<UUID> { Set.fromIter(Iter.fromArray(ids), Set.thash) });
            
            Set.toArrayMap(vote_ids, func(vote_id: UUID) : ?VoteType {
                switch(filter){
                    case(null) {};
                    case(?filter) {
                        if (not Set.has(filter, Set.thash, vote_id)){
                            return null;
                        };
                    };
                };
                Map.get(vote_register.votes, Map.thash, vote_id);
            });
        };

        public func find_vote(vote_id: UUID) : ?VoteType {
            Map.get(vote_register.votes, Map.thash, vote_id);
        };

        public func find_ballot(ballot_id: UUID) : ?BallotType {
            Map.get(ballot_register.ballots, Map.thash, ballot_id);
        };

        public func get_clock() : Clock.Clock {
            clock;
        };

        public func set_timer_interval({ caller: Principal; interval_s: Nat; }) : async* Result<(), Text> {
            await* protocol_timer.set_interval({ caller; interval_s; fn = run;});
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
                last_run = lock_scheduler.get_last_dispense();
                btc_locked = lock_scheduler.get_total_locked();
                dsn_minted = minting_info.amount_minted;
            };
        };

    };

};