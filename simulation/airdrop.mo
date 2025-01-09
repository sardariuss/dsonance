import Map "mo:map/Map";

import Result "mo:base/Result";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Option "mo:base/Option";
import Time "mo:base/Time";

import ckBTC "canister:ck_btc";

module {

    type Result<Ok, Err> = Result.Result<Ok, Err>;

    public type AirdropInfo = {
        var allowed_per_user: Nat;
        var total_distributed: Nat;
        map_distributed: Map.Map<Principal, Nat>;
    };

    public type SAirdropInfo = {
        allowed_per_user: Nat;
        total_distributed: Nat;
        map_distributed: [(Principal, Nat)];
    };

    public class Airdrop(infos: AirdropInfo) {
    
        public func airdropUser(principal: Principal) : async Result<Nat, Text> {

            if (Principal.isAnonymous(principal)){
                return #err("Cannot airdrop to an anonymous principal");
            };

            let distributed : Int = Option.get(Map.get(infos.map_distributed, Map.phash, principal), 0);
            
            let difference = infos.allowed_per_user - distributed;
            
            if (difference <= 0) {
                return #err("Already airdropped user to the maximum allowed!");
            };

            let amount = Int.abs(difference);

            let transfer = await ckBTC.icrc1_transfer({
                from_subaccount = null;
                to = {
                    owner = principal;
                    subaccount = null;
                };
                amount;
                fee = null;
                memo = null;
                created_at_time = ?Nat64.fromNat(Int.abs(Time.now()));
            });

            switch(transfer){
                case(#Err(err)){ 
                    #err("Airdrop transfer failed: " # debug_show(err)); 
                };
                case(#Ok(_)){
                    Map.set(infos.map_distributed, Map.phash, principal, infos.allowed_per_user);
                    infos.total_distributed += amount;
                    #ok(amount); 
                };
            };

        };

        public func isAirdropAvailable(principal: Principal) : Bool {

            if (Principal.isAnonymous(principal)){
                return false;
            };
            
            let distributed : Int = Option.get(Map.get(infos.map_distributed, Map.phash, principal), 0);
            
            let difference = infos.allowed_per_user - distributed;
            
            difference > 0;
        };

        public func getAirdropInfo(): SAirdropInfo {
            return {
                allowed_per_user = infos.allowed_per_user;
                total_distributed = infos.total_distributed;
                map_distributed = Map.toArray(infos.map_distributed) 
            };
        };

        public func setAirdropPerUser({ amount : Nat; }) {
            infos.allowed_per_user := amount;
        };

    };
};