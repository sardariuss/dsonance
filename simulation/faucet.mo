import Principal "mo:base/Principal";
import ICRC1 "mo:icrc1-mo/ICRC1/service";
import Map "mo:map/Map";
import Debug "mo:base/Debug";
import { phash } "mo:map/Map";

shared({caller = admin}) persistent actor class Faucet({
    canister_ids: { 
        ckbtc_ledger: Principal;
        ckusdt_ledger: Principal;
        twv_ledger: Principal;
    };
    ckbtc_mint_amount: Nat;
    ckusdt_mint_amount: Nat;
}) {

    type Account = {
        owner : Principal;
        subaccount : ?Blob;
    };

    let btc_minted = Map.new<Principal, Bool>();
    let usdt_minted = Map.new<Principal, Bool>();

    public shared func admin_mint_btc({to: Account; amount: Nat;}) : async ICRC1.TransferResult {

        // Ideally this function would be restricted to admin only but it is required by
        // the scenario tests to mint btc for multiple users. So for now we leave it unrestricted.
        
        let ckBTCLedger : ICRC1.service = actor(Principal.toText(canister_ids.ckbtc_ledger));

        let result = await ckBTCLedger.icrc1_transfer({
            fee = null;
            memo = null;
            from_subaccount = null;
            created_at_time = null;
            amount = amount;
            to;
        });

        result;
    };

    public shared func admin_mint_usdt({to: Account; amount: Nat;}) : async ICRC1.TransferResult {

        // Ideally this function would be restricted to admin only but it is required by
        // the scenario tests to mint usdt for multiple users. So for now we leave it unrestricted.

        let ckUSDTLedger : ICRC1.service = actor(Principal.toText(canister_ids.ckusdt_ledger));

        let result = await ckUSDTLedger.icrc1_transfer({
            fee = null;
            memo = null;
            from_subaccount = null;
            created_at_time = null;
            amount = amount;
            to;
        });

        result;
    };

    public shared func admin_mint_twv({to: Account; amount: Nat;}) : async ICRC1.TransferResult {

        // Ideally this function would be restricted to admin only but it is required by
        // the scenario tests to mint twv for multiple users. So for now we leave it unrestricted.

        let TWVLedger : ICRC1.service = actor(Principal.toText(canister_ids.twv_ledger));

        let result = await TWVLedger.icrc1_transfer({
            fee = null;
            memo = null;
            from_subaccount = null;
            created_at_time = null;
            amount = amount;
            to;
        });

        result;
    };

    public shared func mint_btc(to: Account) : async ICRC1.TransferResult {

        // Check if user already minted
        switch (Map.get(btc_minted, phash, to.owner)) {
            case (?true) {
                return #Err(#GenericError({ error_code = 1; message = "Already minted ckBTC" }));
            };
            case (_) {};
        };

        let ckBTCLedger : ICRC1.service = actor(Principal.toText(canister_ids.ckbtc_ledger));

        let result = await ckBTCLedger.icrc1_transfer({
            fee = null;
            memo = null;
            from_subaccount = null;
            created_at_time = null;
            amount = ckbtc_mint_amount;
            to;
        });

        // Mark as minted if successful
        switch (result) {
            case (#Ok(_)) {
                Map.set(btc_minted, phash, to.owner, true);
            };
            case (_) {};
        };

        result;
    };

    public shared func mint_usdt(to: Account) : async ICRC1.TransferResult {

        // Check if user already minted
        switch (Map.get(usdt_minted, phash, to.owner)) {
            case (?true) {
                return #Err(#GenericError({ error_code = 1; message = "Already minted ckUSDT" }));
            };
            case (_) {};
        };

        let ckUSDTLedger : ICRC1.service = actor(Principal.toText(canister_ids.ckusdt_ledger));

        let result = await ckUSDTLedger.icrc1_transfer({
            fee = null;
            memo = null;
            from_subaccount = null;
            created_at_time = null;
            amount = ckusdt_mint_amount;
            to;
        });

        // Mark as minted if successful
        switch (result) {
            case (#Ok(_)) {
                Map.set(usdt_minted, phash, to.owner, true);
            };
            case (_) {};
        };

        result;
    };

    // Provided so that the useFungibleLedger types work correctly
    public shared func mint_twv(_: Account) : async ICRC1.TransferResult {
        return #Err(#GenericError({ error_code = 2; message = "TWV minting not supported" }));
    };

    public query func has_minted_btc(user: Principal) : async Bool {
        switch (Map.get(btc_minted, phash, user)) {
            case (?minted) { minted };
            case (null) { false };
        };
    };

    public query func has_minted_usdt(user: Principal) : async Bool {
        switch (Map.get(usdt_minted, phash, user)) {
            case (?minted) { minted };
            case (null) { false };
        };
    };

    public query func has_minted_twv(_: Principal) : async Bool {
        // TWV minting is not supported
        false;
    };

};