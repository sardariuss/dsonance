import Types  "Types";

import Result "mo:base/Result";
import Debug  "mo:base/Debug";
import Float  "mo:base/Float";
import Nat8   "mo:base/Nat8";
import Buffer   "mo:base/Buffer";
import Array    "mo:base/Array";
import Int      "mo:base/Int";

module {

    type IDex            = Types.IDex;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type ILedgerFungible = Types.ILedgerFungible;
    type TrackedPrice    = Types.TrackedPrice;
    
    type PriceObservation = {
        timestamp: Int;
        price: Float;
    };

    type TWAPConfig = {
        window_duration_ns: Nat;
        max_observations: Nat;
    };

    type TrackedTWAPPrice = {
        var spot_price: ?Float;
        var observations: [PriceObservation];
        var twap_cache: ?Float;
        var last_twap_calculation: Int;
    };
    
    public class SpotPriceTracker({
        dex: IDex;
        tracked_price: TrackedPrice;
        pay_ledger: ILedgerFungible;
        receive_ledger: ILedgerFungible;
    })  : Types.IPriceTracker {

        public func fetch_price() : async* Result<(), Text>{
            tracked_price.value := switch(await* query_price({ dex; pay_ledger; receive_ledger })) {
                case(#err(error)) { return #err(error); };
                case(#ok(token_price)) { ?token_price; };
            };
            #ok;
        };

        public func get_price() : Float {
            switch(tracked_price.value) {
                case(?value) { value; };
                case(null) { Debug.trap("Price not set"); };
            }
        };

    };
    
    public class TWAPPriceTracker({
        dex: IDex;
        tracked_twap_price: TrackedTWAPPrice;
        twap_config: TWAPConfig;
        pay_ledger: ILedgerFungible;
        receive_ledger: ILedgerFungible;
        get_current_time: () -> Int;
    })  : Types.IPriceTracker {

        public func fetch_price() : async* Result<(), Text>{
            let current_time = get_current_time();
            
            let normalized_price = switch(await* query_price({ dex; pay_ledger; receive_ledger })){
                case(#err(error)) { return #err(error); };
                case(#ok(token_price)) { token_price; };
            };
            
            // Update spot price with normalized value
            tracked_twap_price.spot_price := ?normalized_price;
            
            // Add new observation with normalized price
            let new_observation = { timestamp = current_time; price = normalized_price; };
            add_observation(new_observation);
            
            // Clear TWAP cache to force recalculation
            tracked_twap_price.twap_cache := null;
            
            #ok;
        };

        /// Returns the TWAP price in units
        /// For example, if pay_ledger is ckBTC (8 decimals) and receive_ledger is ckUSDT (6 decimals),
        /// this returns the TWAP price in "micro-USDT per satoshi" rather than "USDT per BTC"
        public func get_price() : Float {
            get_twap_price();
        };

        public func get_spot_price() : Float {
            switch(tracked_twap_price.spot_price) {
                case(?value) { value; };
                case(null) { Debug.trap("Spot price not set"); };
            }
        };

        public func get_twap_price() : Float {
            let current_time = get_current_time();
            
            // Check if we can use cached TWAP (within same time period)
            switch(tracked_twap_price.twap_cache) {
                case(?cached_twap) {
                    if (current_time == tracked_twap_price.last_twap_calculation) {
                        return cached_twap;
                    };
                };
                case(null) {};
            };
            
            let twap = calculate_twap(current_time);
            
            // Cache the result
            tracked_twap_price.twap_cache := ?twap;
            tracked_twap_price.last_twap_calculation := current_time;
            
            twap;
        };

        public func get_observations_count() : Nat {
            tracked_twap_price.observations.size();
        };

        // TODO: this function could be optimized by only using one buffer, adding previous observations and
        // stopping when either the window duration is reached or the max observations is reached.
        func add_observation(obs: PriceObservation) {
            let buffer = Buffer.fromArray<PriceObservation>(tracked_twap_price.observations);
            buffer.add(obs);
            
            // Remove old observations outside the window
            let current_time = obs.timestamp;
            let window_start = current_time - twap_config.window_duration_ns;
            
            let filtered_buffer = Buffer.Buffer<PriceObservation>(buffer.size());
            for (observation in buffer.vals()) {
                if (observation.timestamp >= window_start) {
                    filtered_buffer.add(observation);
                };
            };
            
            // Limit to max observations
            let final_observations = if (filtered_buffer.size() > twap_config.max_observations) {
                let start_index = Int.abs(filtered_buffer.size() - twap_config.max_observations);
                let all_observations = Buffer.toArray(filtered_buffer);
                let sliced_observations = Array.tabulate<PriceObservation>(
                    twap_config.max_observations,
                    func(i: Nat) : PriceObservation {
                        all_observations[start_index + i];
                    }
                );
                Buffer.fromArray<PriceObservation>(sliced_observations);
            } else {
                filtered_buffer;
            };
            
            tracked_twap_price.observations := Buffer.toArray(final_observations);
        };

        func calculate_twap(_current_time: Int) : Float {
            let observations = tracked_twap_price.observations;
            
            if (observations.size() == 0) {
                Debug.trap("No price observations available for TWAP calculation");
            };
            
            if (observations.size() == 1) {
                return observations[0].price;
            };
            
            // Calculate time-weighted average
            var total_weighted_price : Float = 0.0;
            var total_time_weight : Float = 0.0;
            
            // Sort observations by timestamp (should already be sorted but ensure it)
            let sorted_observations = Array.sort(observations, func(a: PriceObservation, b: PriceObservation) : {#less; #equal; #greater} {
                if (a.timestamp < b.timestamp) { #less }
                else if (a.timestamp > b.timestamp) { #greater }
                else { #equal }
            });
            
            // Calculate TWAP using trapezoidal method
            for (i in sorted_observations.keys()) {
                if (i > 0) {
                    let prev_obs = sorted_observations[i - 1];
                    let curr_obs = sorted_observations[i];
                    
                    let time_diff = Float.fromInt(curr_obs.timestamp - prev_obs.timestamp);
                    let avg_price = (prev_obs.price + curr_obs.price) / 2.0;
                    
                    total_weighted_price += avg_price * time_diff;
                    total_time_weight += time_diff;
                };
            };
            
            if (total_time_weight == 0.0) {
                // Fallback to simple average if no time differences
                var sum : Float = 0.0;
                for (obs in sorted_observations.vals()) {
                    sum += obs.price;
                };
                // Guard against division by zero
                if (sorted_observations.size() == 0) {
                    Debug.trap("No observations available for average calculation");
                };
                return sum / Float.fromInt(sorted_observations.size());
            };
            
            total_weighted_price / total_time_weight;
        };

    };

    // Convert from token price to unit price for use with raw amounts in calculations
    // token_price is in "receive_tokens per pay_token" (e.g., 50,000 USDT per BTC)
    // unit_price should be in "receive_units per pay_unit" (e.g., micro-USDT per satoshi)
    func query_price({ dex: IDex; pay_ledger: ILedgerFungible; receive_ledger: ILedgerFungible }) : async* Result<Float, Text> {
        
        let pay_token_info = pay_ledger.get_token_info();
        let receive_token_info = receive_ledger.get_token_info();

        // Fetch the current spot price
        let preview = await* dex.swap_amounts(pay_token_info.token_symbol, 1, receive_token_info.token_symbol);
        let token_price = switch(preview) {
            case(#err(error)) { return #err(error); };
            case(#ok(reply)) { 
                // Guard against invalid prices
                if (reply.mid_price <= 0.0) {
                    return #err("Invalid price received from DEX: " # Float.toText(reply.mid_price));
                };
                reply.mid_price; 
            }
        };

        // unit_price = token_price * (10^receive_decimals) / (10^pay_decimals)
        let receive_multiplier = Float.fromInt(10 ** Nat8.toNat(receive_token_info.decimals));
        let pay_divisor = Float.fromInt(10 ** Nat8.toNat(pay_token_info.decimals));
        let unit_price = token_price * receive_multiplier / pay_divisor;
        #ok(unit_price);
    }

};