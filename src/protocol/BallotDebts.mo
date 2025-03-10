import Types "Types";
import DebtProcessor "DebtProcessor";
import BallotUtils "votes/BallotUtils";

import Map "mo:map/Map";
import Debug "mo:base/Debug";

module {

    type UUID = Types.UUID;
    type Account = Types.Account;
    type BallotRegister = Types.BallotRegister;

    type DebtType = {
        #BTC;
        #DSN;
    };

    public class BallotDebts({
        btc_debt: DebtProcessor.DebtProcessor;
        dsn_debt: DebtProcessor.DebtProcessor;
        ballot_register: BallotRegister;
    }){

        public func add_debt({ ballot_id: UUID; amount: Float; timestamp: Nat; debt_type: DebtType; }) {
            
            // Get the debt junctions
            let { debt_junctions; debt_processor; } = switch(debt_type){
                case(#BTC) { { debt_junctions = ballot_register.debt_junctions.btc; debt_processor = btc_debt; };};
                case(#DSN) { { debt_junctions = ballot_register.debt_junctions.dsn; debt_processor = dsn_debt; };};
            };
            
            // Get or create the debt for that ballot
            let id = switch(Map.get(debt_junctions, Map.thash, ballot_id)){
                case(null) { 
                    // Get the ballot info
                    let ballot = switch(Map.get(ballot_register.ballots, Map.thash, ballot_id)){
                        case(null) { Debug.trap("Ballot not found"); };
                        case(?b) { BallotUtils.unwrap_yes_no(b); };
                    };
                    // Create a new debt
                    let debt_id = debt_processor.new_debt({ time = ballot.timestamp; account = ballot.from; });
                    // Add a junction
                    Map.set(debt_junctions, Map.thash, ballot_id, debt_id);
                    debt_id;
                };
                case(?debt_id) { debt_id; };
            };

            debt_processor.increase_debt({ id; amount; time = timestamp; });
        };

    };
};