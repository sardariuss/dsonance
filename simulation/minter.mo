import Airdrop "airdrop";

import ckBTC "canister:ck_btc";

import Map "mo:map/Map";

import Result "mo:base/Result";
import Debug "mo:base/Debug";

shared({ caller = owner }) actor class Minter() {

    type Account = {
        owner : Principal;
        subaccount : ?Blob;
    };
    type SAirdropInfo = Airdrop.SAirdropInfo;
    type Result<Ok, Err> = Result.Result<Ok, Err>;

    stable var state = {
        airdrop_info = {
            var allowed_per_user = 1_000_000;
            var total_distributed = 0;
            map_distributed = Map.new<Principal, Nat>();
        };
        var is_restricted = false;
    };

    let airdrop = Airdrop.Airdrop(state.airdrop_info);

    public shared({caller}) func mint({amount: Nat; to: Account}) : async ckBTC.TransferResult {
        
        if (state.is_restricted and caller != owner) {
            Debug.trap("Only the owner of the canister can call this function!");
        };

        await ckBTC.icrc1_transfer({
            fee = null;
            memo = null;
            from_subaccount = null;
            created_at_time = null;
            amount;
            to;
        });
    };

    public query({caller}) func is_airdrop_available() : async Bool {
        airdrop.isAirdropAvailable(caller);
    };

    public shared({caller}) func airdrop_user() : async Result<Nat, Text> {
        await airdrop.airdropUser(caller);
    };

    public query func get_airdrop_info(): async SAirdropInfo {
        airdrop.getAirdropInfo();
    };

    public shared({caller}) func set_airdrop_per_user({ amount : Nat; }) : async Result<(), Text> {
        if (caller != owner) {
            return #err("Only the owner of the canister can call this function!");
        };
        airdrop.setAirdropPerUser({amount});
        #ok;
    };

    public func set_restricted(is_restricted : Bool) {
        state.is_restricted := is_restricted;
    };

};