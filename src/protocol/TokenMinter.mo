import Types "Types";
import DebtProcessor "DebtProcessor";
import LockScheduler "LockScheduler2";
import ProtocolTimer "ProtocolTimer";

import Debug "mo:base/Debug";
import Float "mo:base/Float";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Result "mo:base/Result";

import Map "mo:map/Map";

module {

    type UUID = Types.UUID;
    type Lock = Types.Lock;
    type YesNoBallot = Types.Ballot<Types.YesNoChoice>;
    type ProtocolParameters = Types.ProtocolParameters;
    type VoteType = Types.VoteType;
    type YesNoVote = Types.YesNoVote;
    type DebtRecord = Types.DebtRecord;
    type TimerParameters = Types.TimerParameters;

    type Map<K, V> = Map.Map<K, V>;
    type Result<Ok, Err> = Result.Result<Ok, Err>;

    type Args = {
        admin: Principal;
        lock_scheduler: LockScheduler.LockScheduler;
        parameters: ProtocolParameters and TimerParameters;
        var time_last_mint: Nat;
        dsn_debt: DebtProcessor.DebtProcessor;
        votes: Map<UUID, VoteType>;
        get_ballot: (UUID) -> YesNoBallot;
    };

    public class TokenMinter(args: Args) {

        let { admin; lock_scheduler; dsn_debt; votes; parameters; get_ballot; } = args;
        let protocol_timer = ProtocolTimer.ProtocolTimer({ admin; parameters; });

        public func set_minting_period_s({ caller: Principal; minting_period_s: Nat; }) : async* Result<(), Text> {
            await* protocol_timer.set_interval({ caller; interval_s = minting_period_s; });
        };

        public func start_minting({ caller: Principal; }) : async* Result<(), Text> {
            await* protocol_timer.start_timer({ caller; fn = func() : async* () {
                mint_period();
            }});
        };

        public func stop_minting({ caller: Principal }) : Result<(), Text> {
            protocol_timer.stop_timer({ caller; })
        };

        public func preview_contribution(ballot: YesNoBallot) : DebtRecord {

            let mint_coupon = compute_contribution(ballot, 0).ballot;
            {
                earned = mint_coupon.to_mint;
                pending = mint_coupon.pending;
            };
        };

        func mint_period() {

            let time = Int.abs(Time.now()); // TODO: use the clock module instead

            let period = time - args.time_last_mint;

            if (period < 0) {
                Debug.trap("Cannot mint on a negative period");
            };

            let locks = lock_scheduler.get_locks();

            for (lock in locks) {

                let ballot = get_ballot(lock.id);
                
                let contribution = compute_contribution(ballot, period);

                dsn_debt.increase_debt({ 
                    id = ballot.ballot_id;
                    account = ballot.from;
                    amount = contribution.ballot.to_mint;
                    pending = contribution.ballot.pending;
                    time;
                });
                
                let vote = get_vote({ vote_id = ballot.vote_id });

                dsn_debt.increase_debt({ 
                    id = vote.vote_id;
                    account = vote.author;
                    amount = contribution.author.to_mint;
                    pending = contribution.author.pending;
                    time;
                });
            };

            // Update the last mint time
            args.time_last_mint := time;
        };

        type MintCoupon = {
            to_mint: Float;
            pending: Float;
        };

        type Contribution = {
            ballot: MintCoupon;
            author: MintCoupon;
        };

        func compute_contribution(ballot: YesNoBallot, period: Nat) : Contribution {
            
            let tvl = lock_scheduler.get_tvl();
            
            let release_date = switch(ballot.lock){
                case(null) { Debug.trap("The ballot does not have a lock"); };
                case(?lock) { lock.release_date; };
            };
            
            let { contribution_per_ns } = parameters;

            let rate = (Float.fromInt(ballot.amount) / Float.fromInt(tvl)) * contribution_per_ns;
            let to_mint = rate * Float.fromInt(period);
            let pending = rate * Float.fromInt(release_date - ballot.timestamp);

            {
                ballot = { 
                    to_mint = to_mint * ( 1.0 - parameters.author_share);
                    pending = pending * ( 1.0 - parameters.author_share);
                };
                author = { 
                    to_mint = to_mint * parameters.author_share;
                    pending = pending * parameters.author_share;
                };
            };
        };

        func get_vote({ vote_id: UUID; }) : YesNoVote {
            switch(Map.get(votes, Map.thash, vote_id)){
                case(null) { Debug.trap("The vote does not exist"); };
                case(?v) { 
                    switch(v){
                        case(#YES_NO(vote)) { vote; };
                    };
                };
            };
        };

    };

};