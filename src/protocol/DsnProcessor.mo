import Types "Types";
import DebtProcessor "DebtProcessor";

import Map "mo:map/Map";
import Debug "mo:base/Debug";

module {

    type UUID = Types.UUID;
    type Account = Types.Account;
    type VoteRegister = Types.VoteRegister;
    type BallotRegister = Types.BallotRegister;
    type VoteType = Types.VoteType;
    type YesNoBallot = Types.YesNoBallot;

    type Map<K, V> = Map.Map<K, V>;

    type DebtType = {
        #BTC;
        #DSN;
    };

    public class DsnProcessor({
        debt_processor: DebtProcessor.DebtProcessor;
        vote_register: VoteRegister;
        ballot_register: BallotRegister;
        opening_vote_contribution_ratio: Float;
    }){

        public func process_lock({ ballot: YesNoBallot; amount: Float; time: Nat; }) {

            increase_debt({ 
                elem_id = ballot.vote_id;
                junctions = vote_register.debt_junctions.dsn;
                account = vote_author(ballot.vote_id);
                amount = opening_vote_contribution_ratio * amount;
                time;
            });

            increase_debt({ 
                elem_id = ballot.ballot_id;
                junctions = ballot_register.debt_junctions.dsn;
                account = ballot.from;
                amount = (1 - opening_vote_contribution_ratio) * amount;
                time;
            });
        };

        func increase_debt({ elem_id: UUID; junctions: Map<UUID, Nat>; account: Account; amount: Float; time: Nat;  }) {
            // Get or create the debt for that ballot
            let id = switch(Map.get(junctions, Map.thash, elem_id)){
                case(null) {       
                    // Create a new debt
                    let debt_id = debt_processor.new_debt({ time; account; });
                    // Add a junction
                    Map.set(junctions, Map.thash, elem_id, debt_id);
                    debt_id;
                };
                case(?debt_id) { debt_id; };
            };
                
            debt_processor.increase_debt({ id; amount; time; });
        };

        func vote_author(vote_id: UUID) : Account {
            switch(Map.get(vote_register.votes, Map.thash, vote_id)){
                case(null) { Debug.trap("Vote not found"); };
                case(?v) {
                    switch(v){
                        case(#YES_NO(vote)) { vote.author; };
                    };
                };
            };
        };

    };
};