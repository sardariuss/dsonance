import Principal "mo:base/Principal";
import Result "mo:base/Result";

import LedgerTypes "ledger/Types";

module {

    type Result<Ok, Err> = Result.Result<Ok, Err>;

    public func wrapLedgerFungible(ledger_actor : LedgerTypes.LedgerFungibleActor) : LedgerTypes.ILedgerFungible {
        {
            icrc1_balance_of = func(account: LedgerTypes.Account) : async* Nat {
                await ledger_actor.icrc1_balance_of(account);
            };
            icrc1_transfer = func(args: LedgerTypes.Icrc1TransferArgs) : async* Result<Nat, LedgerTypes.TransferError> {
                Result.fromUpper(await ledger_actor.icrc1_transfer(args));
            };
            icrc2_transfer_from = func(args: LedgerTypes.TransferFromArgs) : async* Result<Nat, LedgerTypes.TransferFromError> {
                Result.fromUpper(await ledger_actor.icrc2_transfer_from(args));
            };
        };
    };

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