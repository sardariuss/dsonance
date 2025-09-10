import Int         "mo:base/Int";
import Float       "mo:base/Float";
import Result      "mo:base/Result";
import Debug       "mo:base/Debug";

import Types       "Types";
import LedgerTypes "../ledger/Types";

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
        fees_account: Account;
        unclaimed_fees: { var value: Float; };
    }) : ISwapReceivable {

        public func get_available_liquidities() : async* Nat {
            let supply_balance = await* ledger_account.get_balance();
            let unclaimed_fees = get_unclaimed_fees();
            let diff : Int = supply_balance - unclaimed_fees;
            if (diff < 0){
                return 0;
            };
            Int.abs(diff);
        };

        // @todo: need a function to get the balance of the subaccount

        public func transfer({
            to: Account;
            amount: Nat;
        }) : async* TransferResult {
            (await* ledger_account.transfer({ amount; to; })).result;
        };

        public func get_unclaimed_fees() : Nat {
            if (unclaimed_fees.value < 0.0) {
                Debug.trap("Invariant broken: unclaimed_fees is negative: " # debug_show(unclaimed_fees.value));
            };
            Int.abs(Float.toInt(unclaimed_fees.value));
        };

        public func claim_fees() : async* TransferResult {
            let fees_amount = get_unclaimed_fees();
            unclaimed_fees.value -= Float.fromInt(fees_amount);
            switch((await* ledger_account.transfer({ 
                amount = fees_amount; 
                to = fees_account;
            })).result){
                case(#ok(tx_id)){ #ok(tx_id); };
                case(#err(err)) {
                    unclaimed_fees.value += Float.fromInt(fees_amount);
                    #err(err);
                };
            };
        };

        public func withdraw_fees({
            caller: Principal;
            to: Account;
            amount: Nat;
        }) : async* TransferResult {

            if (caller != admin) {
                return #err("The caller is not the admin of the protocol");
            };

           (await* ledger_account.transfer({ amount; to; })).result;
        };

        public func pull(args : PullArgs and { protocol_fees: ?Float; }) : async* PullResult {
            let fees_amount = switch(args.protocol_fees){
                case(null) { 0.0; };
                case(?f) { f; };
            };
            if (fees_amount > Float.fromInt(args.amount)) {
                return #err("Fees amount cannot be greater than the pulled amount");
            };
            let tx_id = switch(await* ledger_account.pull(args)){
                case(#err(err)) { return #err(err); };
                case(#ok(tx)) { tx; };
            };
            unclaimed_fees.value += fees_amount;
            #ok(tx_id);
        };

        public func perform_swap(payload: SwapPayload) : async* Result<SwapReply, Text> {
            await* ledger_account.perform_swap(payload);
        };

    };

};