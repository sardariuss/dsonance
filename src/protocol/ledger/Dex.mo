import Result    "mo:base/Result";
import Principal "mo:base/Principal";

import Types "Types";
import KongTypes "../kong/Types";

module {

    type Result<Ok, Err>   = Result.Result<Ok, Err>;
    type KongBackendActor  = KongTypes.KongBackendActor;
    type KongDataActor     = KongTypes.KongDataActor;
    type SendArgs          = Types.SendArgs;
    type SendReply         = Types.SendReply;
    type TxsReply          = Types.TxsReply;
    type IDex              = Types.IDex;
    type SwapAmountsReply  = Types.SwapAmountsReply;
    type AugmentedSwapArgs = Types.AugmentedSwapArgs;
    type SwapReply         = Types.SwapReply;
    type Account           = Types.Account;

    public class Dex({ kong_backend: KongBackendActor; kong_data: KongDataActor }) : IDex {

        public func swap_amounts(pay_token: Text, pay_amount: Nat, receive_token: Text) : async* Result<SwapAmountsReply, Text> {
            Result.fromUpper(await kong_backend.swap_amounts(pay_token, pay_amount, receive_token));
        };

        public func swap(args: AugmentedSwapArgs) : async* Result<SwapReply, Text> {
            Result.fromUpper(await kong_backend.swap(args));
        };

        public func send(args: SendArgs) : async* Result<SendReply, Text> {
            Result.fromUpper(await kong_backend.send(args));
        };

        public func txs(principal_id: ?Text, tx_id: ?Nat64, token_id: ?Nat32, num_txs: ?Nat16) : async* Result<[TxsReply], Text> {
            Result.fromUpper(await kong_data.txs(principal_id, tx_id, token_id, num_txs));
        };

        public func get_main_account() : Account {
            { 
                owner = Principal.fromActor(kong_backend);
                subaccount = null;
            };
        };
        
    };

}