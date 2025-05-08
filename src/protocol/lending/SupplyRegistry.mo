import Nat "mo:base/Nat";
import Debug "mo:base/Debug";
import Result "mo:base/Result";
import Float "mo:base/Float";

import Map "mo:map/Map";
import Set "mo:map/Set";

import Types "../Types";

module {

    type Account = Types.Account;
    type Result<Ok, Err> = Result.Result<Ok, Err>;

    public type SupplyInput = {
        id: Text;
        account: Account;
        supplied: Nat;
    };

    public type SupplyPosition = SupplyInput and {
        supply_state: SupplyState;
    };

    public type SupplyState = {
        #LOCKED;
        #UNLOCKED: Withdrawal;
    };

    public type Withdrawal = {
        interest: Float;
        withdrawal_state: WithdrawalState;
    };

    public type WithdrawalState = {
        #QUEUED;
        #TRANSFERRING;
        #ERROR: Text;
        #SUCCESS;
    };

    public type SupplyRegister = {
        var total_supplied: Nat;
        positions: Map.Map<Text, SupplyPosition>;
        withdrawal_queue: Set.Set<Text>;
    };

    public class SupplyRegistry(register: SupplyRegister){

        public func get_total_supplied() : Nat {
            register.total_supplied;
        };

        public func get_position({ id: Text }) : ?SupplyPosition {
            Map.get(register.positions, Map.thash, id);
        };

        public func add_position(input: SupplyInput) {

            if (Map.has(register.positions, Map.thash, input.id)){
                Debug.trap("The map already has a position with the ID " # debug_show(input.id));
            };
        
            Map.set(register.positions, Map.thash, input.id, { input with supply_state = #LOCKED; });
            register.total_supplied += input.supplied;
        };

        public func update_unlocked({ id: Text; withdrawal_state: WithdrawalState; }){
            
            let position = switch(Map.get(register.positions, Map.thash, id)){
                case(null) { Debug.trap("The map does not have a position with the ID " # debug_show(id)); };
                case(?p) { p; };
            };
            
            let supply_state = switch(position.supply_state){
                case(#LOCKED) { Debug.trap("Cannot update withdrawal state, the position is locked"); };
                case(#UNLOCKED( { interest; })) {
                    #UNLOCKED({ interest; withdrawal_state; });
                };
            };
            
            Map.set(register.positions, Map.thash, id, { position with supply_state; } );

            // Add or remove to the queue
            switch(withdrawal_state){
                case(#QUEUED)       { Set.add(register.withdrawal_queue,    Set.thash, id); };
                case(#TRANSFERRING) { Set.delete(register.withdrawal_queue, Set.thash, id); };
                case(#ERROR(_))     { Set.add(register.withdrawal_queue,    Set.thash, id); }; // In order to add it back, this design prevents reentry
                case(#SUCCESS)      { register.total_supplied -= position.supplied; }; // Don't forget to update the total supplied on success!
            };
        };

//        public func withdraw_position({ id: Text; interest: Float; }) {
//            
//            let position = switch(Map.remove(register.positions, Map.thash, id)){
//                case(null) { Debug.trap("The map does not have a position with the ID " # debug_show(id)); };
//                case(?p) { p; };
//            };
//
//            // In case the (negative) interest surpass the original amount supplied, no need to transfer
//            if (interest < 0.0 and interest < (-1.0 * Float.fromInt(position.supplied))){
//                Map.set(register.positions, Map.thash, id, { position with state = #UNLOCKED({ interest; withdrawal = #SUCCESS; }) });
//                register.total_supplied -= position.supplied;
//                return;
//            };
//
//            Map.set(register.positions, Map.thash, id, { position with state = #UNLOCKED({ interest; withdrawal = #QUEUED; }) });
//            Set.add(register.withdrawal_queue, Set.thash, id);
//        };
    };

};