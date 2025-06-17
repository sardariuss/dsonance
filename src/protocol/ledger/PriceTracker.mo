import Types  "Types";

import Result "mo:base/Result";
import Debug  "mo:base/Debug";

module {

    type IDex            = Types.IDex;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type ILedgerFungible = Types.ILedgerFungible;
    type TrackedPrice    = Types.TrackedPrice;
    
    public class PriceTracker({
        dex: IDex;
        tracked_price: TrackedPrice;
        pay_ledger: ILedgerFungible;
        receive_ledger: ILedgerFungible;
    })  : Types.IPriceTracker {

        public func fetch_price() : async* Result<(), Text>{
            let preview = await* dex.swap_amounts(pay_ledger.token_symbol(), 1, receive_ledger.token_symbol());
            let price = switch(preview) {
                case(#err(error)) { return #err(error); };
                case(#ok(reply)) { reply.price; }
            };
            tracked_price.value := ?price;
            #ok;
        };

        public func get_price() : Float {
            switch(tracked_price.value) {
                case(?value) { value; };
                case(null) { Debug.trap("Price not set"); };
            }
        };

    };

};