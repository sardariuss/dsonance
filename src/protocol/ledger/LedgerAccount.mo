import Types         "Types";
import Cell          "../utils/Cell";

import Int           "mo:base/Int";
import Result        "mo:base/Result";
import Error         "mo:base/Error";
import Time          "mo:base/Time";
import Nat64         "mo:base/Nat64";

module {

    type Result<Ok, Err>   = Result.Result<Ok, Err>;
    type Cell<T>           = Cell.Cell<T>;
    type Transfer          = Types.Transfer;
    type Account           = Types.Account;
    type TxIndex           = Types.TxIndex;
    type PullResult        = Types.PullResult;
    type ILedgerAccount    = Types.ILedgerAccount;
    type ISwapPayable      = Types.ISwapPayable;
    type ISwapReceivable   = Types.ISwapReceivable;
    type Swap              = Types.Swap;
    type SwapPayload       = Types.SwapPayload;
    type IDex              = Types.IDex;
    type SwapReply         = Types.SwapReply;
    type ILedgerFungible   = Types.ILedgerFungible;
    
    // TODO: ideally the LedgerAccount should only implement ILedgerAccount
    public class LedgerAccount({
        protocol_account: Account;
        ledger: ILedgerFungible;
        local_balance: Cell<Nat>;
    }) : ILedgerAccount and ISwapPayable and ISwapReceivable {

        public func get_local_balance() : Nat {
            local_balance.get();
        };

        public func pull({
            from: Account;
            amount: Nat;
        }) : async* PullResult {

            let args = {
                // According to the ICRC2 specifications, if the from account has been approved with a
                // different spender subaccount than the one specified, the transfer will be rejected.
                spender_subaccount = null;
                from;
                to = protocol_account;
                amount;
                fee = ?ledger.fee();
                memo = null;
                created_at_time = ?Nat64.fromNat(Int.abs(Time.now()));
            };

            // Perform the transfer
            // @todo: can this trap ?
            switch(await* ledger.transfer_from(args)){
                case(#err(error)){ #err(error); };
                case(#ok(tx_id)){ 
                    local_balance.set(local_balance.get() + amount);
                    #ok(tx_id); 
                };
            };
        };

        public func transfer({
            amount: Nat;
            to: Account;
        }) : async* Transfer {

            let args = {
                to;
                from_subaccount = null;
                // Deduct the transfer fee from the amount to transfer
                amount = Int.abs(Int.max(amount - ledger.fee(), 0));
                fee = ?ledger.fee();
                memo = null;
                created_at_time = ?Nat64.fromNat(Int.abs(Time.now()));
            };

            if (args.amount == 0) {
                return { args; result = #err(#GenericError({ 
                    error_code = 0; 
                    message = "Amount " # debug_show(amount) # " is too low to cover the transfer fee"; })); 
                };
            };

            // Perform the transfer
            let result = try {
                switch(await* ledger.transfer(args)){
                    case(#err(error)){ #err(error); };
                    case(#ok(tx_id)){
                        local_balance.set(local_balance.get() - amount); 
                        #ok(tx_id); 
                    };
                };
            } catch(err) {
                #err(#Trapped{ error_code = Error.code(err); });
            };

            { args; result; };
        };

        public func perform_swap(payload: SwapPayload) : async* Result<SwapReply, Text> {
            // Check if the from account matches the protocol account
            if (payload.from != protocol_account) {
                return #err("Protocol accounts do not match");
            };
            switch(await* payload.dex.swap({
                from = payload.from;
                pay_token = payload.pay_token;
                pay_amount = payload.amount;
                pay_tx_id = null;
                receive_token = ledger.token_symbol();
                receive_amount = null;
                receive_address = null;
                max_slippage = ?payload.max_slippage;
                referred_by = null;
            })) {
                case(#err(error)){ return #err(error); };
                case(#ok(reply)) {
                    local_balance.set(local_balance.get() + reply.receive_amount);
                    // Call the callback to update the local_balance of the other ledger account
                    payload.callback();
                    #ok(reply);
                };
            };
        };

        public func swap({
            dex: IDex;
            amount: Nat;
            max_slippage: Float;
        }) : Swap {
            
            let payload = {
                from = protocol_account;
                pay_token = ledger.token_symbol();
                amount;
                max_slippage;
                dex;
                callback = func() { local_balance.set(local_balance.get() - amount); };
            };
            {
                against = func(swap_receivable: ISwapReceivable) : async* Result<SwapReply, Text> {
                    await* swap_receivable.perform_swap(payload);
                };
            };
        };

    };

};
