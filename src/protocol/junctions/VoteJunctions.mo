import Types "../Types";

import Map "mo:map/Map";

module {

    type UUID = Types.UUID;
    type VoteRegister = Types.VoteRegister;

    type Map<K, V> = Map.Map<K, V>;

    type JunctionId = {
        #DSN: Nat;
    };

    type JunctionType = {
        #DSN;
    };

    public class VoteJunctions({
        vote_register: VoteRegister;
    }){

        public func add_junction({ vote_id: UUID; junction_id: JunctionId; }) : ?Nat {
            // Add the junction
            switch(junction_id){
                case(#DSN(id)) { 
                    switch(Map.add(vote_register.junctions.dsn_debts, Map.thash, vote_id, id)){
                        case(null) { null };
                        case(?prev) { ?prev; };
                    }
                };
            };
        };

        public func set_junction({ vote_id: UUID; junction_id: JunctionId }) {
            // Set the junction
            switch(junction_id){
                case(#DSN(id)) { Map.set(vote_register.junctions.dsn_debts, Map.thash, vote_id, id); };
            };
        };

        public func get_junction({ vote_id: UUID; junction_type: JunctionType; }) : ?Nat {
            // Get the junction
            switch(junction_type){
                case(#DSN) { Map.get(vote_register.junctions.dsn_debts, Map.thash, vote_id); };
            };
        };

    };
};