import Types "Types";
import DebtProcessor "DebtProcessor";
import Duration "duration/Duration";

import Debug "mo:base/Debug";
import Float "mo:base/Float";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Result "mo:base/Result";
import Timer "mo:base/Timer";
import Iter "mo:base/Iter";

import Map "mo:map/Map";

module {

    type UUID = Types.UUID;
    type YesNoBallot = Types.Ballot<Types.YesNoChoice>;
    type ProtocolParameters = Types.ProtocolParameters;
    type VoteType = Types.VoteType;
    type YesNoVote = Types.YesNoVote;
    type DebtRecord = Types.DebtRecord;
    type TimerParameters = Types.TimerParameters;
    type MinterParameters = Types.MinterParameters;
    type Duration = Types.Duration;
    
    type Iter<T> = Iter.Iter<T>;
    type Map<K, V> = Map.Map<K, V>;
    type Result<Ok, Err> = Result.Result<Ok, Err>;

    public class TokenMinter({
        parameters: MinterParameters;
        dsn_debt: DebtProcessor.DebtProcessor;
        get_tvl: () -> Nat;
        get_locked_ballots: () -> Iter<(YesNoBallot, YesNoVote)>;
    }) {
        // @todo: update amount minted;

        var timer_id: ?Timer.TimerId = null;

        public func set_minting_period(minting_period: Duration) : async* () {
            ignore stop_minting();
            parameters.minting_period := minting_period;
            ignore (await* start_minting());
        };

        public func start_minting() : async* Result<(), Text> {
            switch(timer_id) {
                case(null) {
                    let interval_ns = Duration.toTime(parameters.minting_period);
                    timer_id := ?Timer.recurringTimer<system>(#nanoseconds(interval_ns), func() : async () {
                        await* mint();
                    });
                    #ok;
                };
                case(_) { 
                    #err("Minting process is currently active"); 
                };
            }
        };

        public func stop_minting() : Result<(), Text> {
            switch(timer_id) {
                case(?id) { 
                    Timer.cancelTimer(id);
                    timer_id := null;
                    #ok;
                };
                case(null) {
                    #err("No minting process is currently active");
                };
            };
        };

        public func preview_contribution(ballot: YesNoBallot) : DebtRecord {

            let mint_coupon = compute_contribution(ballot, 0, get_tvl()).ballot;
            {
                earned = mint_coupon.to_mint;
                pending = mint_coupon.pending;
            };
        };

        func mint() : async*() {

            let time = Int.abs(Time.now()); // TODO: use the clock module instead

            let period = do {
                let diff : Int = time - parameters.time_last_mint;
                if (diff < 0) {
                    Debug.trap("Cannot mint on a negative period");
                };
                Int.abs(diff);
            };
            
            let tvl = get_tvl();

            for ((ballot, vote) in get_locked_ballots()) {
                
                let contribution = compute_contribution(ballot, period, tvl);

                dsn_debt.increase_debt({ 
                    id = ballot.ballot_id;
                    account = ballot.from;
                    amount = contribution.ballot.to_mint;
                    pending = contribution.ballot.pending;
                    time;
                });

                dsn_debt.increase_debt({ 
                    id = vote.vote_id;
                    account = vote.author;
                    amount = contribution.author.to_mint;
                    pending = contribution.author.pending;
                    time;
                });
            };    

            // Update the last mint time
            parameters.time_last_mint := time;

            await* dsn_debt.transfer_pending();
        };

        type MintCoupon = {
            to_mint: Float;
            pending: Float;
        };

        type Contribution = {
            ballot: MintCoupon;
            author: MintCoupon;
        };

        func compute_contribution(ballot: YesNoBallot, period: Nat, tvl: Nat) : Contribution {
            
            let release_date = switch(ballot.lock){
                case(null) { Debug.trap("The ballot does not have a lock"); };
                case(?lock) { lock.release_date; };
            };

            let rate = (Float.fromInt(ballot.amount * parameters.contribution_per_day * Duration.NS_IN_DAY) / Float.fromInt(tvl));
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

    };

};