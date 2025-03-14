import Types "../Types";

import Map "mo:map/Map";

module {

    type UUID = Types.UUID;
    type BallotRegister = Types.BallotRegister;

    type Map<K, V> = Map.Map<K, V>;

    type JunctionId = {
        #BTC: Nat;
        #DSN: Nat;
    };

    type JunctionType = {
        #BTC;
        #DSN;
    };

    public class BallotJunctions({
        ballot_register: BallotRegister;
    }){

        public func add_junction({ ballot_id: UUID; junction_id: JunctionId; }) : ?Nat {
            let (junction_register, id) = switch(junction_id){
                case(#BTC(id)) { 
                    (ballot_register.junctions.btc_debts, id);
                };
                case(#DSN(id)) { 
                    (ballot_register.junctions.dsn_debts, id);
                };
            };
            Map.add(junction_register, Map.thash, ballot_id, id);
        };

        public func set_junction({ ballot_id: UUID; junction_id: JunctionId; }) {
            let (junction_register, id) = switch(junction_id){
                case(#BTC(id)) { 
                    (ballot_register.junctions.btc_debts, id);
                };
                case(#DSN(id)) { 
                    (ballot_register.junctions.dsn_debts, id);
                };
            };
            Map.set(junction_register, Map.thash, ballot_id, id);
        };

        public func get_junction({ ballot_id: UUID; junction_type: JunctionType; }) : ?Nat {
            let junction_register = switch(junction_type){
                case(#BTC) { ballot_register.junctions.btc_debts; };
                case(#DSN) { ballot_register.junctions.dsn_debts; };
            };
            Map.get(junction_register, Map.thash, ballot_id);
        };

    };
};