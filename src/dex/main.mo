import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Float "mo:base/Float";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";

import LedgerTypes "../protocol/ledger/Types";

import ICRC1              "mo:icrc1-mo/ICRC1/service";
import ICRC2              "mo:icrc2-mo/ICRC2/service";

shared actor class Dex({ canister_ids: { ck_btc: Principal; ck_usdt: Principal; }}) = this {

    type SwapAmountsTxReply = {
        pool_symbol: Text;
        pay_chain: Text;
        pay_symbol: Text;
        pay_address: Text;
        pay_amount: Nat;
        receive_chain: Text;
        receive_symbol: Text;
        receive_address: Text;
        receive_amount: Nat;
        price: Float;
        lp_fee: Nat;
        gas_fee: Nat;
    };

    let ckBTC : ICRC1.service and ICRC2.service = actor(Principal.toText(canister_ids.ck_btc));
    let ckUSDT : ICRC1.service and ICRC2.service = actor(Principal.toText(canister_ids.ck_usdt));

    // Helper to get ledger and symbol
    func get_ledger(token: Text) : ICRC1.service and ICRC2.service {
        if (token == "ckBTC") return ckBTC;
        if (token == "ckUSDT") return ckUSDT;
        Debug.trap("Token not supported");
    };

    // Helper to get pool reserves
    func get_reserves() : async (Nat, Nat) {
        let btc_balance = await ckBTC.icrc1_balance_of({owner = Principal.fromActor(this); subaccount = null});
        let usdt_balance = await ckUSDT.icrc1_balance_of({owner = Principal.fromActor(this); subaccount = null});
        (btc_balance, usdt_balance)
    };

    // Constant product formula: x * y = k
    // Returns (amount_out, price, slippage)
    func get_amount_out(
        pay_token: Text,
        pay_amount: Nat,
        btc_reserve: Nat,
        usdt_reserve: Nat
    ) : (Nat, Float, Float) {
        let (x, y) = if (pay_token == "ckBTC") (btc_reserve, usdt_reserve) else (usdt_reserve, btc_reserve);
        let amount_in = pay_amount;
        let amount_in_with_fee = amount_in * 997 / 1000; // 0.3% fee
        let numerator = amount_in_with_fee * y;
        let denominator = x + amount_in_with_fee;
        let amount_out = numerator / denominator;
        // Price and slippage estimation
        let price = if (pay_token == "ckBTC") {
            Float.fromInt(usdt_reserve) / Float.fromInt(btc_reserve)
        } else {
            Float.fromInt(btc_reserve) / Float.fromInt(usdt_reserve)
        };
        let new_x = x + amount_in_with_fee;
        let new_y : Int = y - amount_out;
        let new_price = Float.fromInt(new_y) / Float.fromInt(new_x);
        let slippage = Float.abs((new_price - price) / price);
        (amount_out, price, slippage)
    };

    // swap_amounts: preview a swap
    public func swap_amounts(
        pay_token: Text,
        pay_amount: Nat,
        receive_token: Text
    ) : async { 
        #Ok: {
            pay_chain: Text;
            pay_symbol: Text;
            pay_address: Text;
            pay_amount: Nat;
            receive_chain: Text;
            receive_symbol: Text;
            receive_address: Text;
            receive_amount: Nat;
            price: Float;
            mid_price: Float;
            slippage: Float;
            txs: [SwapAmountsTxReply];
        }; 
        #Err: Text 
    } {
        if (not(pay_token == "ckBTC" and receive_token == "ckUSDT") and not(pay_token == "ckUSDT" and receive_token == "ckBTC")) {
            Debug.trap("Token pair " # pay_token # " / " # receive_token # " not supported");
        };
        let (btc_reserve, usdt_reserve) = await get_reserves();
        let (amount_out, price, slippage) = get_amount_out(pay_token, pay_amount, btc_reserve, usdt_reserve);
        #Ok({
            pay_chain = "IC";
            pay_symbol = pay_token;
            pay_address = Principal.toText(Principal.fromActor(this));
            pay_amount = pay_amount;
            receive_chain = "IC";
            receive_symbol = receive_token;
            receive_address = Principal.toText(Principal.fromActor(this));
            receive_amount = amount_out;
            price = price;
            mid_price = price; // Mid price is the same as the price in this case
            slippage = slippage;
            txs = []; // No transactions in preview
        })
    };

    // swap: perform the swap
    public shared({caller}) func swap(args: {
        pay_token: Text;
        pay_amount: Nat;
        pay_tx_id: ?{ BlockIndex : Nat; TransactionId : Text };
        receive_token: Text;
        receive_amount: ?Nat;
        receive_address: ?Text;
        max_slippage: ?Float;
        referred_by: ?Text;
    }) : async { #Ok : {
        tx_id : Nat64;
        request_id : Nat64;
        status : Text;
        pay_chain : Text;
        pay_address : Text;
        pay_symbol : Text;
        pay_amount : Nat;
        receive_chain : Text;
        receive_address : Text;
        receive_symbol : Text;
        receive_amount : Nat;
        mid_price : Float;
        price : Float;
        slippage : Float;
        txs : [LedgerTypes.SwapTxReply];
        transfer_ids : [LedgerTypes.TransferIdReply];
        claim_ids : [Nat64];
        ts : Nat64;
    }; #Err : Text } {

        if (not(args.pay_token == "ckBTC" and args.receive_token == "ckUSDT") and not(args.pay_token == "ckUSDT" and args.receive_token == "ckBTC")) {
            Debug.trap("Token pair " # args.pay_token # " / " # args.receive_token # " not supported");
        };

        // Pull tokens from user
        let pay_ledger = get_ledger(args.pay_token);
        let receive_ledger = get_ledger(args.receive_token);

        // Get pool reserves before swap
        let (btc_reserve, usdt_reserve) = await get_reserves();
        let (amount_out, price, slippage) = get_amount_out(args.pay_token, args.pay_amount, btc_reserve, usdt_reserve);

        // Check slippage
        switch (args.max_slippage) {
            case (?max) {
                if (slippage > max) return #Err("Slippage too high");
            };
            case null {};
        };

        // Transfer pay_token from user to pool
        let transfer_from_args = {
            spender_subaccount = null;
            from = { owner = caller; subaccount = null };
            to = { owner = Principal.fromActor(this); subaccount = null };
            amount = args.pay_amount;
            fee = null;
            memo = null;
            created_at_time = ?Nat64.fromNat(Int.abs(Time.now()));
        };
        let transfer_from_result = await pay_ledger.icrc2_transfer_from(transfer_from_args);
        switch (transfer_from_result) {
            case (#Err(err)) return #Err("Transfer from user failed: " # debug_show(err));
            case (#Ok(_)) {};
        };

        // Transfer receive_token from pool to user
        let transfer_args = {
            to = { owner = caller; subaccount = null };
            from_subaccount = null;
            amount = amount_out;
            fee = null;
            memo = null;
            created_at_time = ?Nat64.fromNat(Int.abs(Time.now()));
        };
        let transfer_result = await receive_ledger.icrc1_transfer(transfer_args);
        switch (transfer_result) {
            case (#Ok(tx_id)) {
                #Ok({
                    tx_id = Nat64.fromNat(tx_id);
                    request_id = 0;
                    status = "success";
                    pay_chain = "IC";
                    pay_address = Principal.toText(caller);
                    pay_symbol = args.pay_token;
                    pay_amount = args.pay_amount;
                    receive_chain = "IC";
                    receive_address = Principal.toText(caller);
                    receive_symbol = args.receive_token;
                    receive_amount = amount_out;
                    mid_price = price;
                    price = price;
                    slippage = slippage;
                    txs = [];
                    transfer_ids = [];
                    claim_ids = [];
                    ts = Nat64.fromNat(Int.abs(Time.now()));
                })
            };
            case (#Err(err)) return #Err("Transfer to user failed: " # debug_show(err));
        }
    };
};