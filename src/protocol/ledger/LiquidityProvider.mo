import Types "Types";
import Result "mo:base/Result";

module {

    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type ILedgerAccount = Types.ILedgerAccount;
    type Account = Types.Account;
    type IDex = Types.IDex;

    public class LiquidityProvider({
        supply_account: ILedgerAccount; // Need special subaccount for supply tokens
        collateral_account: ILedgerAccount; // Need special subaccount for collateral tokens to partition funds from the rest
        dex: IDex;
    }) {

        public func add_liquidity(user: Account, supply_amount: Nat, collateral_amount: Nat) : async* Result<(), Text> {

            #ok;

        };

    };
};