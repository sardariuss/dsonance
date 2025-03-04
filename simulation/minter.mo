import Airdrop "airdrop";

import Map "mo:map/Map";

import Result "mo:base/Result";
import Debug "mo:base/Debug";

import ckBTC "canister:ck_btc";
import dsnLedger "canister:dsn_ledger";

shared({ caller = owner }) actor class Minter() {

    type Account = {
        owner : Principal;
        subaccount : ?Blob;
    };
    type SAirdropInfo = Airdrop.SAirdropInfo;
    type Result<Ok, Err> = Result.Result<Ok, Err>;

    stable var state = {
        btc_airdrop_info = {
            var allowed_per_user = 1_000_000;
            var total_distributed = 0;
            map_distributed = Map.new<Principal, Nat>();
        };
        dsn_airdrop_info = {
            var allowed_per_user = 100_000_000_000;
            var total_distributed = 0;
            map_distributed = Map.new<Principal, Nat>();
        };
        var is_restricted = false;
    };

    let btc_airdrop = Airdrop.Airdrop({ info = state.btc_airdrop_info; ledger = ckBTC; });
    let dsn_airdrop = Airdrop.Airdrop({ info = state.dsn_airdrop_info; ledger = dsnLedger; });

    public shared({caller}) func mint_btc({amount: Nat; to: Account}) : async ckBTC.TransferResult {
        
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

    public shared({caller}) func mint_dsn({amount: Nat; to: Account}) : async dsnLedger.TransferResult {
        
        if (state.is_restricted and caller != owner) {
            Debug.trap("Only the owner of the canister can call this function!");
        };

        await dsnLedger.icrc1_transfer({
            fee = null;
            memo = null;
            from_subaccount = null;
            created_at_time = null;
            amount;
            to;
        });
    };

    public query({caller}) func is_btc_airdrop_available() : async Bool {
        btc_airdrop.isAirdropAvailable(caller);
    };

    public shared({caller}) func btc_airdrop_user() : async Result<Nat, Text> {
        await btc_airdrop.airdropUser(caller);
    };

    public query func get_btc_airdrop_info(): async SAirdropInfo {
        btc_airdrop.getAirdropInfo();
    };

    public shared({caller}) func set_btc_airdrop_per_user({ amount : Nat; }) : async Result<(), Text> {
        if (caller != owner) {
            return #err("Only the owner of the canister can call this function!");
        };
        btc_airdrop.setAirdropPerUser({amount});
        #ok;
    };

        public query({caller}) func is_dsn_airdrop_available() : async Bool {
        dsn_airdrop.isAirdropAvailable(caller);
    };

    public shared({caller}) func dsn_airdrop_user() : async Result<Nat, Text> {
        await dsn_airdrop.airdropUser(caller);
    };

    public query func get_dsn_airdrop_info(): async SAirdropInfo {
        dsn_airdrop.getAirdropInfo();
    };

    public shared({caller}) func set_dsn_airdrop_per_user({ amount : Nat; }) : async Result<(), Text> {
        if (caller != owner) {
            return #err("Only the owner of the canister can call this function!");
        };
        dsn_airdrop.setAirdropPerUser({amount});
        #ok;
    };

    public func set_restricted(is_restricted : Bool) {
        state.is_restricted := is_restricted;
    };

};