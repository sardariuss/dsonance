import Types "Types";
import DebtProcessor "DebtProcessor";
import Duration "duration/Duration";
import Timeline "utils/Timeline";

import Debug "mo:base/Debug";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Result "mo:base/Result";

import Map "mo:map/Map";

module {

    type UUID = Types.UUID;
    type YesNoBallot = Types.Ballot<Types.YesNoChoice>;
    type ProtocolParameters = Types.ProtocolParameters;
    type VoteType = Types.VoteType;
    type YesNoVote = Types.YesNoVote;
    type DebtRecord = Types.DebtRecord;
    type MinterParameters = Types.MinterParameters;
    type Duration = Types.Duration;
    
    type Iter<T> = Map.Iter<T>;
    type Map<K, V> = Map.Map<K, V>;
    type Result<Ok, Err> = Result.Result<Ok, Err>;

    type MintCoupon = {
        to_mint: Float;
        pending: Float;
    };

    type Contribution = {
        ballot: MintCoupon;
        author: MintCoupon;
    };

    public class TokenMinter({
        parameters: MinterParameters;
        dsn_debt: DebtProcessor.DebtProcessor;
    }) {

        public func preview_contribution(ballot: YesNoBallot, tvl: Nat) : DebtRecord {

            let mint_coupon = compute_contribution({ballot; time = 0; period = 0; tvl = tvl + ballot.amount}).ballot;
            {
                earned = mint_coupon.to_mint;
                pending = mint_coupon.pending;
            };
        };

        public func mint({
            time: Nat;
            locked_ballots: Iter<(YesNoBallot, YesNoVote)>;
            tvl: Nat;
        }) {

            let period = do {
                let diff : Int = time - parameters.time_last_mint;
                if (diff < 0) {
                    Debug.trap("Cannot mint on a negative period");
                };
                if (diff == 0) {
                    Debug.print("No time has passed since the last mint.");
                    return;
                };
                Int.abs(diff);
            };
            
            var total_period = 0.0;

            for ((ballot, vote) in locked_ballots) {
                
                let contribution = compute_contribution({ballot; time; period; tvl});

                total_period += contribution.ballot.to_mint + contribution.author.to_mint;

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
            
            // Update the total amount minted and last mint time
            Timeline.insert(parameters.amount_minted, time, Timeline.current(parameters.amount_minted) + total_period);
            parameters.time_last_mint := time;
        };

        func compute_contribution({ballot: YesNoBallot; time: Nat; period: Nat; tvl: Nat; }) : Contribution {
            
            let release_date = switch(ballot.lock){
                case(null) { Debug.trap("The ballot does not have a lock"); };
                case(?lock) { lock.release_date; };
            };

            let rate = (Float.fromInt(ballot.amount) / Float.fromInt(tvl)) * (Float.fromInt(parameters.contribution_per_day) / Float.fromInt(Duration.NS_IN_DAY));
            let to_mint = rate * Float.fromInt(period);
            let pending = rate * Float.fromInt(release_date - time);

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