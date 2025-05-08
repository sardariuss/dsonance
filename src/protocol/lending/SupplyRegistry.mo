import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";

import Map "mo:map/Map";

import MapUtils "../utils/Map";
import Types "../Types";

module {

    type Account = Types.Account;

    public type SupplyPosition = {
        account: Account;
        supplied: Nat;
    };

    public type SupplyRegister = {
        var total_supplied: Nat;
        map: Map.Map<Account, SupplyPosition>; 
    };

    public class SupplyRegistry(register: SupplyRegister){

        public func get_total_supplied() : Nat {
            register.total_supplied;
        };

        public func get_position({ account: Account; }) : ?SupplyPosition {
            Map.get(register.map, MapUtils.acchash, account);
        };

        // Merge if there is already a position for that account
        public func add_supply(position: SupplyPosition) : SupplyPosition {
            
            let updated_position = switch(Map.get(register.map, MapUtils.acchash, position.account)){
                case(null) { position; };
                case(?old) {
                    { old with supplied = old.supplied + position.supplied };
                };
            };
            register.total_supplied += position.supplied;
            Map.set(register.map, MapUtils.acchash, position.account, updated_position);
            updated_position;
        };

        // Traps if the slash amount is greater than the position supply
        // Remove the position if the slash amount is equal to the position supply
        // Return the updated position otherwise
        public func slash_supply({ account: Account; amount: Nat; }) : ?SupplyPosition {
            
            let position = switch(Map.get(register.map, MapUtils.acchash, account)){
                case(null) { Debug.trap("No position to slash"); };
                case(?old) { old; };
            };

            let supply_diff : Int = position.supplied - amount;

            if (supply_diff < 0) {
                Debug.trap("Insufficient supply to slash");
            };

            register.total_supplied -= amount;

            if (supply_diff == 0){
                Debug.print("Supply slashed completely");
                Map.delete(register.map, MapUtils.acchash, account);
                return null;
            };
            
            let updated_position = { position with supplied = Int.abs(supply_diff); };
            Map.set(register.map, MapUtils.acchash, account, updated_position);
            ?updated_position;
        };
    };

};