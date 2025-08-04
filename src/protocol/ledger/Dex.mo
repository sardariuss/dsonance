import Result    "mo:base/Result";
import Principal "mo:base/Principal";

import Types "Types";
import KongTypes "../kong/Types";

module {

    type Result<Ok, Err>   = Result.Result<Ok, Err>;
    type KongBackendActor  = KongTypes.KongBackendActor;
    type IDex              = Types.IDex;
    type SwapAmountsReply  = Types.SwapAmountsReply;
    type AugmentedSwapArgs = Types.AugmentedSwapArgs;
    type SwapReply         = Types.SwapReply;
    type Account           = Types.Account;

    public class Dex({ kong_backend: KongBackendActor }) : IDex {

        public func swap_amounts(pay_token: Text, pay_amount: Nat, receive_token: Text) : async* Result<SwapAmountsReply, Text> {
            Result.fromUpper(await kong_backend.swap_amounts(pay_token, pay_amount, receive_token));
        };

        public func swap(args: AugmentedSwapArgs) : async* Result<SwapReply, Text> {
            Result.fromUpper(await kong_backend.swap(args));
        };

        public func get_main_account() : Account {
            { 
                owner = Principal.fromActor(kong_backend);
                subaccount = null;
            };
        };
        
    };

}