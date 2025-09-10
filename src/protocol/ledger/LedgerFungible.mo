import Result "mo:base/Result";
import Debug "mo:base/Debug";

import Types "Types";
import ErrorConverter "../utils/ErrorConverter";

module {

    type Result<Ok, Err> = Result.Result<Ok, Err>;


    let ICRC1_METADATA_SYMBOL_KEY = "icrc1:symbol";

    // TODO: use try/catch to handle errors in the async functions
    public class LedgerFungible(ledger_actor : Types.LedgerFungibleActor) : Types.ILedgerFungible {

        var ledger_info : ?Types.LedgerInfo = null;

        public func initialize() : async* Result<(), Text> {
            // Check if already initialized
            switch(ledger_info){
                case(null) {};
                case(?_) { return #err("LedgerFungible.initialize: LedgerFungible is already initialized"); };
            };
            // Query the fee
            let fee = await* query_token_fee(ledger_actor);
            // Query the token symbol from metadata
            let token_symbol = switch (await* query_token_symbol(ledger_actor)) {
                case (#err(e)) { return #err("init_ledger_info: " # e); };
                case (#ok(s)) { s; };
            };
            // Query the token decimals
            let decimals = await* query_token_decimals(ledger_actor);
            // Initialize the ledger info
            ledger_info := ?{ fee; token_symbol; decimals; };
            Debug.print("LedgerFungible.init_ledger_info: Initialized ledger info with fee " # debug_show(fee) # ", token symbol " # debug_show(token_symbol) # ", and decimals " # debug_show(decimals));
            #ok;
        };

        public func get_token_info() : Types.LedgerInfo {
            switch (ledger_info) {
                case (null) { Debug.trap("LedgerFungible.get_token_info: LedgerFungible is not initialized"); };
                case (?info) { info; };
            };
        };

        public func balance_of(account: Types.Account) : async* Nat {
            await ledger_actor.icrc1_balance_of(account);
        };

        public func transfer(args: Types.Icrc1TransferArgs) : async* Result<Nat, Text> {
            switch(Result.fromUpper(await ledger_actor.icrc1_transfer(args))) {
                case (#ok(value)) { #ok(value) };
                case (#err(error)) { #err(ErrorConverter.transferErrorToText(error)) };
            };
        };

        public func transfer_from(args: Types.TransferFromArgs) : async* Result<Nat, Text> {
            switch(Result.fromUpper(await ledger_actor.icrc2_transfer_from(args))) {
                case (#ok(value)) { #ok(value) };
                case (#err(error)) { #err(ErrorConverter.transferFromErrorToText(error)) };
            };
        };

        public func approve(args: Types.ApproveArgs) : async* Result<Nat, Text> {
            switch(Result.fromUpper(await ledger_actor.icrc2_approve(args))) {
                case (#ok(value)) { #ok(value) };
                case (#err(error)) { #err(ErrorConverter.approveErrorToText(error)) };
            };
        };
        
    };

    func query_token_fee(ledger_actor : Types.LedgerFungibleActor) : async* Nat {
        await ledger_actor.icrc1_fee();
    };

    func query_token_decimals(ledger_actor : Types.LedgerFungibleActor) : async* Nat8 {
        await ledger_actor.icrc1_decimals();
    };

    func query_token_symbol(ledger_actor : Types.LedgerFungibleActor) : async* Result<Text, Text> {
        let metadata = await ledger_actor.icrc1_metadata();
        var opt_token_symbol : ?Text = null;
        for ((key, value) in metadata.vals()){
            if (key == ICRC1_METADATA_SYMBOL_KEY){
                switch(value){
                    case(#Text(t)){
                        opt_token_symbol := ?t;
                    };
                    case(_){
                        return #err("query_token_symbol: Metadata value for symbol is not a Text");
                    };
                };
            };
        };
        switch(opt_token_symbol){
            case(null) { return #err("query_token_symbol: Token symbol not found in metadata"); };
            case(?s) { return #ok(s); };
        };
    };

};