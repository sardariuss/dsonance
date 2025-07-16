import Debug       "mo:base/Debug";
import Int         "mo:base/Int";
import Float       "mo:base/Float";
import Result      "mo:base/Result";

import Types       "Types";
import Indexer     "Indexer";
import LedgerTypes "../ledger/Types";
import Math        "../utils/Math";

module {

    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type Account         = Types.Account;
    type TransferResult  = LedgerTypes.TransferResult;
    type Transfer        = LedgerTypes.Transfer;
    type PullArgs        = LedgerTypes.PullArgs;
    type PullResult      = LedgerTypes.PullResult;
    type TransferArgs    = LedgerTypes.TransferArgs;
    type SwapPayload     = LedgerTypes.SwapPayload;
    type SwapReply       = LedgerTypes.SwapReply;
    type PrepareSwapArgs = LedgerTypes.PrepareSwapArgs;
    type ILedgerAccount  = LedgerTypes.ILedgerAccount;
    type ISwapReceivable = LedgerTypes.ISwapReceivable;
    type Swap            = LedgerTypes.Swap;
    
    public class SupplyAccount({
        admin: Principal;
        ledger_account: ILedgerAccount and ISwapReceivable;
        indexer: Indexer.Indexer;
    }) : ISwapReceivable {
        
        public func get_balance() : Nat {
            let supply_balance = ledger_account.get_local_balance();
            let interest_fees = Math.ceil_to_int(indexer.get_index().accrued_interests.fees);
            if (supply_balance <= interest_fees) {
                Debug.print("Not enough balance to transfer withdrawals, available balance: " # Int.toText(supply_balance) # ", fees: " # Int.toText(interest_fees));
                return 0;
            };
            Int.abs(supply_balance - interest_fees);
        };

        public func transfer({
            to: Account;
            amount: Nat;
        }) : async* TransferResult {

            if (amount > get_balance()) {
                return #err(#GenericError({ error_code = 0; message = "Not enough supply available to transfer"; }));
            };

            (await* ledger_account.transfer({ amount; to; })).result;
        };

        public func get_available_fees() : Nat {
            Int.abs(Float.toInt(indexer.get_index().accrued_interests.fees));
        };

        public func withdraw_fees({
            caller: Principal;
            to: Account;
            amount: Nat;
        }) : async* TransferResult {

            if (caller != admin) {
                return #err(#GenericError({ error_code = 0; message = "Caller is not the admin of the protocol"; }));
            };
            
            let revert_take_fees = switch(indexer.take_supply_fees(amount)){
                case(#err(error)) { return #err(#GenericError({ error_code = 0; message = error; })); };
                case(#ok({revert})) { revert; };
            };

            switch((await* ledger_account.transfer({ amount; to; })).result){
                case(#err(error)) { 
                    // Revert the fees if the transfer fails
                    revert_take_fees();
                    #err(error); 
                };
                case(#ok(tx_id)) {
                    #ok(tx_id);
                };
            };
        };

        public func pull(args : PullArgs) : async* PullResult {
            await* ledger_account.pull(args);
        };

        public func perform_swap(payload: SwapPayload) : async* Result<SwapReply, Text> {
            await* ledger_account.perform_swap(payload);
        };

    };

};