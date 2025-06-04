import Int "mo:base/Int";
import Float "mo:base/Float";
import Debug "mo:base/Debug";
import Option "mo:base/Option";

import LedgerTypes "../../src/protocol/ledger/Types";
import LedgerAccounting "LedgerAccounting";

module {

    type LedgerConfig = {
        pay_token: Text;
        pay_accounting: LedgerAccounting.LedgerAccounting;
        receive_token: Text;
        receive_accounting: LedgerAccounting.LedgerAccounting;
    };

    type Account = LedgerTypes.Account;
    type AugmentedSwapArgs = LedgerTypes.SwapArgs and { from: Account; };

    func equal_configs(a: LedgerTypes.PriceArgs, b: LedgerTypes.PriceArgs) : Bool {
        (a.pay_token == b.pay_token) and (a.receive_token == b.receive_token)
    };
    
    // TODO: have a map of tokens instead
    public class DexFake({ account: Account; config: LedgerConfig; init_price: Float; }) : LedgerTypes.IDex {
        
        var price : Float = init_price;

        public func set_price(new_price: Float) {
            price := new_price;
        };

        public func last_price(args: LedgerTypes.PriceArgs) : Float {
            if (not equal_configs(args, config)) {
                Debug.trap("swap_amounts called with unexpected tokens: " # args.pay_token # " and " # args.receive_token);
            };
            price
        };

        public func swap_amounts(pay_token: Text, pay_amount: Nat, receive_token: Text) : async* LedgerTypes.SwapAmountsResult {
            
            if (not equal_configs({ pay_token; receive_token; }, config)) {
                Debug.trap("swap_amounts called with unexpected tokens: " # pay_token # " and " # receive_token);
            };
            
            let receive_amount = Int.abs(Float.toInt(Float.fromInt(pay_amount) * price));

            let reply : LedgerTypes.SwapAmountsReply = {
                pay_chain = "IC";
                pay_symbol = pay_token;
                pay_address = "";
                pay_amount = pay_amount;
                receive_chain = "IC";
                receive_symbol = receive_token;
                receive_address = "";
                receive_amount = receive_amount;
                price = price;
                mid_price = price;
                slippage = 0.0;
                txs = [];
            };
            #Ok(reply)
        };

        public func swap(args: AugmentedSwapArgs) : async* LedgerTypes.SwapResult {

            if (not equal_configs(args, config)) {
                Debug.trap("swap_amounts called with unexpected tokens: " # args.pay_token # " and " # args.receive_token);
            };

            let receive_amount = switch(args.receive_amount) {
                case (null) { Int.abs(Float.toInt(Float.fromInt(args.pay_amount) * price)) };
                case (_) { Debug.trap("receive_amount is not supported by DexFake (yet)"); };
            };

            let #ok(_) = config.pay_accounting.transfer({
                from = args.from;
                to = account;
                amount = args.pay_amount;
            }) else return #Err("Swap: failed to transfer pay amount");

            let #ok(_) = config.receive_accounting.transfer({
                from = account;
                to = args.from;
                amount = receive_amount;
            }) else return #Err("Swap: failed to transfer receive amount");

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
                mid_price = price;
                price = price;
                slippage = 0.0;
                txs = [];
                transfer_ids = [];
                claim_ids = [];
                ts = 0;
            };
            #Ok(reply)
        };
    };
};
