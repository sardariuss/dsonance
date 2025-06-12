import Result "mo:base/Result";

import LedgerTypes "ledger/Types";

module {

    type Result<Ok, Err> = Result.Result<Ok, Err>;

    public func wrapDex(dex_actor: LedgerTypes.DexActor) : LedgerTypes.IDex {
        {
            swap_amounts = func(pay_token: Text, pay_amount: Nat, receive_token: Text) : async* Result<LedgerTypes.SwapAmountsReply, Text> {
                Result.fromUpper(await dex_actor.swap_amounts(pay_token, pay_amount, receive_token));
            };
            swap = func(args: LedgerTypes.AugmentedSwapArgs) : async* Result<LedgerTypes.SwapReply, Text> {
                Result.fromUpper(await dex_actor.swap(args));
            };
            last_price = func(args: LedgerTypes.PriceArgs) : Float {
                110_000; // @todo
            };
        };
    };

}