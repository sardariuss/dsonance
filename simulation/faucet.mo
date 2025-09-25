import Principal "mo:base/Principal";
import ICRC1 "mo:icrc1-mo/ICRC1/service";

shared persistent actor class Faucet({ canister_ids: { ckbtc_ledger: Principal; ckusdt_ledger: Principal; tvw_ledger: Principal; } }) {

    type Account = {
        owner : Principal;
        subaccount : ?Blob;
    };

    public shared func mint_btc({amount: Nat; to: Account}) : async ICRC1.TransferResult {

        let ckBTCLedger : ICRC1.service = actor(Principal.toText(canister_ids.ckbtc_ledger));

        await ckBTCLedger.icrc1_transfer({
            fee = null;
            memo = null;
            from_subaccount = null;
            created_at_time = null;
            amount;
            to;
        });
    };

    public shared func mint_usdt({amount: Nat; to: Account}) : async ICRC1.TransferResult {

        let ckUSDTLedger : ICRC1.service = actor(Principal.toText(canister_ids.ckusdt_ledger));

        await ckUSDTLedger.icrc1_transfer({
            fee = null;
            memo = null;
            from_subaccount = null;
            created_at_time = null;
            amount;
            to;
        });
    };

    public shared func mint_twv({amount: Nat; to: Account}) : async ICRC1.TransferResult {

        let twvLedger : ICRC1.service = actor(Principal.toText(canister_ids.tvw_ledger));

        await twvLedger.icrc1_transfer({
            fee = null;
            memo = null;
            from_subaccount = null;
            created_at_time = null;
            amount;
            to;
        });
    };

};