import Int "mo:base/Int";
import Float "mo:base/Float";
import Debug "mo:base/Debug";
import Option "mo:base/Option";
import Result "mo:base/Result";

import LedgerTypes "../../src/protocol/ledger/Types";
import LedgerAccounting "LedgerAccounting";

module {

    type Result<Ok, Err> = Result.Result<Ok, Err>;

    type LedgerConfig = {
        pay_token: Text;
        pay_accounting: LedgerAccounting.LedgerAccounting;
        receive_token: Text;
        receive_accounting: LedgerAccounting.LedgerAccounting;
    };

    type Account = LedgerTypes.Account;
    type AugmentedSwapArgs = LedgerTypes.SwapArgs and { from: Account; };
    type TrackedPrice = LedgerTypes.TrackedPrice;

    func equal_configs(a: LedgerTypes.PriceArgs, b: LedgerTypes.PriceArgs) : Bool {
        (a.pay_token == b.pay_token) and (a.receive_token == b.receive_token)
    };
    
    // TODO: have a map of tokens instead
    public class DexFake({ account: Account; config: LedgerConfig; price: TrackedPrice; }) : LedgerTypes.IDex {

        public func swap_amounts(pay_token: Text, pay_amount: Nat, receive_token: Text) : async* Result<LedgerTypes.SwapAmountsReply, Text> {
            
            if (not equal_configs({ pay_token; receive_token; }, config)) {
                Debug.trap("swap_amounts called with unexpected tokens: " # pay_token # " and " # receive_token);
            };
            
            let receive_amount = Int.abs(Float.toInt(Float.fromInt(pay_amount) * get_price()));

            let reply : LedgerTypes.SwapAmountsReply = {
                pay_chain = "IC";
                pay_symbol = pay_token;
                pay_address = "";
                pay_amount = pay_amount;
                receive_chain = "IC";
                receive_symbol = receive_token;
                receive_address = "";
                receive_amount = receive_amount;
                price = get_price();
                mid_price = get_price();
                slippage = 0.0;
                txs = [];
            };
            #ok(reply)
        };

        public func swap(args: AugmentedSwapArgs) : async* Result<LedgerTypes.SwapReply, Text> {

            if (not equal_configs(args, config)) {
                Debug.trap("swap_amounts called with unexpected tokens: " # args.pay_token # " and " # args.receive_token);
            };

            let receive_amount = switch(args.receive_amount) {
                case (null) { Int.abs(Float.toInt(Float.fromInt(args.pay_amount) * get_price())) };
                case (_) { Debug.trap("receive_amount is not supported by DexFake (yet)"); };
            };

            switch(config.pay_accounting.transfer({
                from = args.from;
                to = account;
                amount = args.pay_amount;
            })){
                case(#err(err)) { return #err("Fail to transfer token 0: " # debug_show(err)); };
                case(#ok(_)) {};
            };

            switch(config.receive_accounting.transfer({
                from = account;
                to = args.from;
                amount = receive_amount;
            })){
                case(#err(err)) { return #err("Fail to transfer token 1: " # debug_show(err)); };
                case(#ok(_)) {};
            };

            let reply : LedgerTypes.SwapReply = {
                tx_id = 0;
                request_id = 0;
                status = "ok";
                pay_chain = "IC";
                pay_address = "";
                pay_symbol = args.pay_token;
                pay_amount = args.pay_amount;
                receive_chain = "IC";
                receive_address = Option.get(args.receive_address, "");
                receive_symbol = args.receive_token;
                receive_amount = receive_amount;
                mid_price = get_price();
                price = get_price();
                slippage = 0.0;
                txs = [];
                transfer_ids = [];
                claim_ids = [];
                ts = 0;
            };
            #ok(reply)
        };

        func get_price() : Float {
            switch(price.value) {
                case(?value) { value; };
                case(null) { Debug.trap("Price not set"); };
            }
        };
    };
};
