import Types                   "Types";
import LockScheduler           "LockScheduler";
import ParticipationMiner      "ParticipationMiner";
import MapUtils                "utils/Map";
import Timeline                "utils/Timeline";
import Clock                   "utils/Clock";
import SharedConversions       "shared/SharedConversions";
import BallotUtils             "votes/BallotUtils";
import VoteTypeController      "votes/VoteTypeController";
import IdFormatter             "IdFormatter";
import IterUtils               "utils/Iter";
import LedgerTypes             "ledger/Types";
import LendingTypes            "lending/Types";
import SupplyRegistry          "lending/SupplyRegistry";
import BorrowRegistry          "lending/BorrowRegistry";
import WithdrawalQueue         "lending/WithdrawalQueue";
import SupplyAccount           "lending/SupplyAccount";
import ForesightUpdater        "ForesightUpdater";

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
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type Parameters = Types.Parameters;
    type Timeline<T> = Types.Timeline<T>;
    type ProtocolInfo = Types.ProtocolInfo;
    type YesNoBallot = Types.YesNoBallot;
    type YesNoVote = Types.YesNoVote;
    type Lock = Types.Lock;
    type Duration = Types.Duration;
    type YieldState = Types.YieldState;
    type PutBallotError = Types.PutBallotError;
    type LoanPosition = LendingTypes.LoanPosition;
    type Loan = LendingTypes.Loan;
    type BorrowOperation = LendingTypes.BorrowOperation;
    type BorrowOperationArgs = LendingTypes.BorrowOperationArgs;
    type TransferResult = LendingTypes.TransferResult;
    type IPriceTracker = LedgerTypes.IPriceTracker;
    type ParticipationTracker = Types.ParticipationTracker;

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
        genesis_time: Nat;
        clock: Clock.Clock;
        vote_register: VoteRegister;
        ballot_register: BallotRegister;
        lock_scheduler: LockScheduler.LockScheduler;
        vote_type_controller: VoteTypeController.VoteTypeController;
        supply: SupplyAccount.SupplyAccount;
        supply_registry: SupplyRegistry.SupplyRegistry;
        borrow_registry: BorrowRegistry.BorrowRegistry;
        withdrawal_queue: WithdrawalQueue.WithdrawalQueue;
        collateral_price_tracker: IPriceTracker;
        participation_miner: ParticipationMiner.ParticipationMiner;
        parameters: Parameters;
        foresight_updater: ForesightUpdater.ForesightUpdater;
    }){

        public func new_vote(args: NewVoteArgs) : async* SNewVoteResult {

            let { type_enum; origin; id; account; } = args;

            let vote_id = IdFormatter.format(#VoteId(id));

            if (Map.has(vote_register.votes, Map.thash, vote_id)){
                return #err("Vote already exists: " # vote_id);
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

            let timestamp = clock.get_time();

            let { ballot_id; vote_type; } = switch(process_ballot_input(args)){
                case(#err(err)) { return #err(err); };
                case(#ok(input)) { input; };
            };

            // TODO: this preview is somehow required to trigger the update of the foresight
            // Why? Because currently the foresight updater is filtering out the items based on the timestamp,
            // adding a position, even with a supplied amount of 0, will update the indexer's timestamp.
            let preview_result = supply_registry.add_position_without_transfer({
                id = ballot_id;
                account = { owner = args.caller; subaccount = args.from_subaccount; };
                // TODO: the supplied amount is set to 0 to not impact the supply APY in the preview, because
                // it can lead to a miscomprehension of the ballot APY preview. Ideally, one should have a way
                // to preview with our without the impact on the supply APY.
                supplied = 0;
            }, timestamp);

            let tx_id = switch(preview_result){
                case(#err(err)) { return #err(err); };
                case(#ok(tx_id)) { tx_id; };
            };

            perform_put_ballot({
                args;
                timestamp;
                vote_type;
                ballot_id;
                tx_id;
            });
        };

        public func put_ballot(args: PutBallotArgs) : async* PutBallotResult {

            let timestamp = clock.get_time();

            let { ballot_id; vote_type; } = switch(process_ballot_input(args)){
                case(#err(err)) { return #err(err); };
                case(#ok(input)) { input; };
            };

            let transfer = await* supply_registry.add_position({
                id = ballot_id;
                account = { owner = args.caller; subaccount = args.from_subaccount; };
                supplied = args.amount;
            }, timestamp);

            let tx_id = switch(transfer){
                case(#err(err)) { return #err(err); };
                case(#ok(tx_id)) { tx_id; };
            };

            perform_put_ballot({
                args;
                timestamp;
                vote_type;
                ballot_id;
                tx_id;
            });
        };

        public func run_borrow_operation(args: BorrowOperationArgs) : async* Result<BorrowOperation, Text> {
            await* borrow_registry.run_operation(clock.get_time(), args);
        };

        public func run_borrow_operation_for_free(args: BorrowOperationArgs) : Result<BorrowOperation, Text> {
            borrow_registry.run_operation_for_free(clock.get_time(), args);
        };

        public func get_loan_position(account: Account) : LoanPosition {
            borrow_registry.get_loan_position(clock.get_time(), account);
        };

        public func get_loans_info() : { positions: [Loan]; max_ltv: Float } {
            borrow_registry.get_loans_info(clock.get_time());
        };

        public func get_available_liquidities() : async* Nat {
            await* supply.get_available_liquidities();
        };

        public func get_unclaimed_fees() : Nat {
            supply.get_unclaimed_fees();
        };

        public func withdraw_fees({ caller: Principal; to: Account; amount: Nat; }) : async* TransferResult {
            await* supply.withdraw_fees({ caller; to; amount; });
        };

        // TODO: make sure none of the methods called in this function can trap:
        // it should only log errors
        public func run() : async* () {
            
            let time = clock.get_time();
            Debug.print("Running controller at time: " # debug_show(time));

            // 1. Liquidate unhealthy loans
            switch(await* collateral_price_tracker.fetch_price()){
                case(#err(error)) { Debug.print("Failed to update collateral price: " # error); };
                case(#ok(_)) {
                    switch(await* borrow_registry.check_all_positions_and_liquidate(time)){
                        case(#err(error)) { Debug.print("Failed to check positions and liquidate: " # error); };
                        case(#ok(_)) {};
                    };
                };
            };
            
            // 2. Update foresights before unlocking, so the rewards are up-to-date
            foresight_updater.update_foresights();
            
            // 3. Unlock expired locks and process them
            let unlocked_ids = lock_scheduler.try_unlock(time);
            
            // 4. Process each unlocked ballot
            label unlock_supply for (ballot_id in Set.keys(unlocked_ids)) {

                let ballot = switch(Map.get(ballot_register.ballots, Map.thash, ballot_id)) {
                    case(null) { 
                        Debug.print("Ballot " # debug_show(ballot_id) # " not found");
                        continue unlock_supply;
                    };
                    case(?#YES_NO(ballot)) { ballot; };
                };
                let { vote_id; } = ballot;

                let vote_type = switch(Map.get(vote_register.votes, Map.thash, vote_id)) {
                    case(null) { 
                        Debug.print("Vote " # debug_show(vote_id) # " not found");
                        continue unlock_supply;
                    };
                    case(?v) { v; };
                };

                vote_type_controller.unlock_ballot({ vote_type; ballot_id; });
                
                // Remove supply position using the ballot's foresight reward
                switch(supply_registry.remove_position({
                    id = ballot_id;
                    interest_amount = Int.abs(ballot.foresight.reward);
                    time;
                })){
                    case(#err(err)) { Debug.print("Failed to remove supply position for ballot " # debug_show(ballot_id) # ": " # err); };
                    case(#ok(_)) {};
                };
            };
            
            switch(await* withdrawal_queue.process_pending_withdrawals(time)){
                case(#err(error)) { Debug.print("Failed to process pending withdrawals: " # error); };
                case(#ok(_)) {};
            };

            // 6. Mint participation tokens
            switch(participation_miner.mine(time)){
                case(#err(error)) { Debug.print("Failed to distribute participation: " # error); };
                case(#ok(_)) {};
            };
        };

        public func withdraw_mined(account: Account) : async* ?Nat {
            await* participation_miner.withdraw(account);
        };

        public func get_participation_trackers() : [(Account, ParticipationTracker)] {
            participation_miner.get_trackers();
        };

        public func get_participation_tracker(account: Account) : ?ParticipationTracker {
            participation_miner.get_tracker(account);
        };

        public func get_clock() : Clock.Clock {
            clock;
        };

        public func get_info() : ProtocolInfo {
            {
                current_time = clock.get_time();
                genesis_time;
            };
        };

        type ProcessedBallotInput = {
            ballot_id: Text;
            vote_type: VoteType;
        };

        func process_ballot_input(args: PutBallotArgs) : Result<ProcessedBallotInput, Text> {
            
            let { id; vote_id; amount; } = args;

            let ballot_id = IdFormatter.format(#BallotId(id));

            let vote_type = switch(Map.get(vote_register.votes, Map.thash, vote_id)){
                case(null) return #err("Vote not found: " # vote_id);
                case(?v) v;
            };

            switch(Map.get(ballot_register.ballots, Map.thash, ballot_id)){
                case(?_) return #err("Ballot already exists: " # ballot_id);
                case(null) {};
            };

            if (amount < parameters.minimum_ballot_amount){
                return #err("Insufficient amount: " # debug_show(amount) # " (minimum: " # debug_show(parameters.minimum_ballot_amount) # ")");
            };

            #ok({
                ballot_id;
                vote_type;
            });
        };

        func perform_put_ballot({
            args: PutBallotArgs;
            timestamp: Nat;
            vote_type: VoteType;
            ballot_id: Text;
            tx_id: Nat;
        }): PutBallotResult {
            
            let from = { owner = args.caller; subaccount = args.from_subaccount };

            let put_ballot = vote_type_controller.put_ballot({
                vote_type;
                choice_type = args.choice_type;
                args = { args with ballot_id; tx_id; timestamp; from };
            });

            ignore lock_scheduler.try_unlock(timestamp);

            lock_scheduler.add(
                BallotUtils.unwrap_lock(put_ballot.new),
                IterUtils.map<BallotType, Lock>(
                    vote_type_controller.vote_ballots(vote_type),
                    BallotUtils.unwrap_lock
                )
            );

            MapUtils.putInnerSet(ballot_register.by_account, MapUtils.acchash, from, Map.thash, ballot_id);

            #ok(SharedConversions.sharePutBallotSuccess(put_ballot));
        };

    };

};