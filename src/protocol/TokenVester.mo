import Types "Types";
import DebtProcessor "DebtProcessor";
import BallotJunctions "./junctions/BallotJunctions";
import VoteJunctions "./junctions/VoteJunctions";

import Debug "mo:base/Debug";

module {

    type YesNoBallot = Types.YesNoBallot;
    type YesNoVote = Types.YesNoVote;

    public class TokenVester({
        debt_processors: {
            btc: DebtProcessor.DebtProcessor;
            dsn: DebtProcessor.DebtProcessor;
        };
        ballot_junctions: BallotJunctions.BallotJunctions;
        vote_junctions: VoteJunctions.VoteJunctions;
    }){

        public func payout_ballot({ ballot: YesNoBallot; time: Nat; btc_amount_e8s: Float; }) {
            
            let { ballot_id; from; } = ballot;

            let debt_id = debt_processors.btc.one_shot_debt({ time; account = from; amount = btc_amount_e8s; });
            switch(ballot_junctions.add_junction({ ballot_id; junction_id = #BTC(debt_id); })){
                case(null) {};
                case(?_) { Debug.trap("Ballots can only be paid out once!"); };
            };
        };

        public func disburse_ballot({ ballot: YesNoBallot; time: Nat; dsn_amount_e8s: Float; finalized: Bool; }) {
            
            let { ballot_id; from; } = ballot;

            // Get or create the debt for that ballot
            let debt_id = switch(ballot_junctions.get_junction({ ballot_id; junction_type = #DSN; })){
                case(null) { debt_processors.dsn.new_debt({ time; account = from; }); };
                case(?id) { id; };
            };

            // Increase the debt amount
            debt_processors.dsn.increase_debt({ id = debt_id; amount = dsn_amount_e8s; time; finalized; });
        };

        public func disburse_author({ vote: YesNoVote; time: Nat; dsn_amount_e8s: Float; }) {

            let { vote_id; author; } = vote;
            
            // Get or create the debt for that vote
            let debt_id = switch(vote_junctions.get_junction({ vote_id; junction_type = #DSN; })){
                case(null) { debt_processors.dsn.new_debt({ time; account = author; }); };
                case(?id) { id; };
            };

            // Increase the debt amount (because votes are never ending, so disbursements are never finalized)
            debt_processors.dsn.increase_debt({ id = debt_id; amount = dsn_amount_e8s; time; finalized = false; });
        };

    };
};