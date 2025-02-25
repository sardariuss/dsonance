import Map "mo:map/Map";

import Result "mo:base/Result";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Option "mo:base/Option";
import Time "mo:base/Time";

import ICRC1 "mo:icrc1-mo/ICRC1/service";

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

    public class Airdrop({
        info: AirdropInfo;
        ledger: ICRC1.service;
    }) {
    
        public func airdropUser(principal: Principal) : async Result<Nat, Text> {

            if (Principal.isAnonymous(principal)){
                return #err("Cannot airdrop to an anonymous principal");
            };

            let distributed : Int = Option.get(Map.get(info.map_distributed, Map.phash, principal), 0);
            
            let difference = info.allowed_per_user - distributed;
            
            if (difference <= 0) {
                return #err("Already airdropped user to the maximum allowed!");
            };

            let amount = Int.abs(difference);

            let transfer = await ledger.icrc1_transfer({
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
                    Map.set(info.map_distributed, Map.phash, principal, info.allowed_per_user);
                    info.total_distributed += amount;
                    #ok(amount); 
                };
            };

        };

        public func isAirdropAvailable(principal: Principal) : Bool {

            if (Principal.isAnonymous(principal)){
                return false;
            };
            
            let distributed : Int = Option.get(Map.get(info.map_distributed, Map.phash, principal), 0);
            
            let difference = info.allowed_per_user - distributed;
            
            difference > 0;
        };

        public func getAirdropInfo(): SAirdropInfo {
            return {
                allowed_per_user = info.allowed_per_user;
                total_distributed = info.total_distributed;
                map_distributed = Map.toArray(info.map_distributed) 
            };
        };

        public func setAirdropPerUser({ amount : Nat; }) {
            info.allowed_per_user := amount;
        };

    };
};