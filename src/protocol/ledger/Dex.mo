import Result    "mo:base/Result";
import Principal "mo:base/Principal";

import Types "Types";

module {

    type Result<Ok, Err>   = Result.Result<Ok, Err>;
    type DexActor          = Types.DexActor;
    type IDex              = Types.IDex;
    type SwapAmountsReply  = Types.SwapAmountsReply;
    type AugmentedSwapArgs = Types.AugmentedSwapArgs;
    type SwapReply         = Types.SwapReply;
    type PriceArgs         = Types.PriceArgs;
    type Account           = Types.Account;

    public class Dex(dex_actor: DexActor) : IDex {
        
        public func swap_amounts(pay_token: Text, pay_amount: Nat, receive_token: Text) : async* Result<SwapAmountsReply, Text> {
            Result.fromUpper(await dex_actor.swap_amounts(pay_token, pay_amount, receive_token));
        };

        public func swap(args: AugmentedSwapArgs) : async* Result<SwapReply, Text> {
            Result.fromUpper(await dex_actor.swap(args));
        };

        public func get_main_account() : Account {
            { 
                owner = Principal.fromActor(dex_actor);
                subaccount = null;
            };
        };
        
    };

}