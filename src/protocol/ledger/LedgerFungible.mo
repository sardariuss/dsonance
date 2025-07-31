import Result "mo:base/Result";
import Debug "mo:base/Debug";

import Types "Types";
import ErrorConverter "../utils/ErrorConverter";

module {

    type Result<Ok, Err> = Result.Result<Ok, Err>;

    type LedgerInfo = {
        fee : Nat;
        token_symbol : Text;
    };

    let ICRC1_METADATA_SYMBOL_KEY = "icrc1:symbol";

    public class LedgerFungible(ledger_actor : Types.LedgerFungibleActor) : Types.ILedgerFungible {

        var ledger_info : ?LedgerInfo = null;

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
            // Initialize the ledger info
            ledger_info := ?{ fee; token_symbol; };
            Debug.print("LedgerFungible.init_ledger_info: Initialized ledger info with fee " # debug_show(fee) # " and token symbol " # debug_show(token_symbol));
            #ok;
        };

        public func fee() : Nat {
            switch (ledger_info) {
                case (null) { Debug.trap("LedgerFungible.fee: LedgerFungible is not initialized"); };
                case (?info) { info.fee; };
            };
        };

        public func token_symbol() : Text {
            switch (ledger_info) {
                case (null) { Debug.trap("LedgerFungible.token_symbol: LedgerFungible is not initialized"); };
                case (?info) { info.token_symbol; };
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

        public func transfer_no_commit(args: Types.Icrc1TransferArgs) : async Result<Nat, Text> {
            switch(Result.fromUpper(await? ledger_actor.icrc1_transfer(args))) {
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