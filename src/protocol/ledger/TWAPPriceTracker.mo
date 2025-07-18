import Types    "Types";
import Buffer   "mo:base/Buffer";
import Result   "mo:base/Result";
import Debug    "mo:base/Debug";
import Array    "mo:base/Array";
import Float    "mo:base/Float";
import Int      "mo:base/Int";

module {

    type IDex            = Types.IDex;
    type Result<Ok, Err> = Result.Result<Ok, Err>;
    type ILedgerFungible = Types.ILedgerFungible;
    type TrackedPrice    = Types.TrackedPrice;
    
    public type PriceObservation = {
        timestamp: Int;
        price: Float;
    };

    public type TWAPConfig = {
        window_duration: Int; // Duration in time units (e.g., seconds)
        max_observations: Nat; // Maximum number of observations to keep
    };

    public type TrackedTWAPPrice = {
        var spot_price: ?Float;
        var observations: [PriceObservation];
        var twap_cache: ?Float;
        var last_twap_calculation: Int;
        config: TWAPConfig;
    };
    
    public class TWAPPriceTracker({
        dex: IDex;
        tracked_twap_price: TrackedTWAPPrice;
        pay_ledger: ILedgerFungible;
        receive_ledger: ILedgerFungible;
        get_current_time: () -> Int;
    })  : Types.IPriceTracker {

        public func fetch_price() : async* Result<(), Text>{
            let current_time = get_current_time();
            
            // Fetch the current spot price
            let preview = await* dex.swap_amounts(pay_ledger.token_symbol(), 1, receive_ledger.token_symbol());
            let price = switch(preview) {
                case(#err(error)) { return #err(error); };
                case(#ok(reply)) { reply.price; }
            };
            
            // Update spot price
            tracked_twap_price.spot_price := ?price;
            
            // Add new observation
            let new_observation = { timestamp = current_time; price = price; };
            add_observation(new_observation);
            
            // Clear TWAP cache to force recalculation
            tracked_twap_price.twap_cache := null;
            
            #ok;
        };

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

        func add_observation(obs: PriceObservation) {
            let buffer = Buffer.fromArray<PriceObservation>(tracked_twap_price.observations);
            buffer.add(obs);
            
            // Remove old observations outside the window
            let current_time = obs.timestamp;
            let window_start = current_time - tracked_twap_price.config.window_duration;
            
            let filtered_buffer = Buffer.Buffer<PriceObservation>(buffer.size());
            for (observation in buffer.vals()) {
                if (observation.timestamp >= window_start) {
                    filtered_buffer.add(observation);
                };
            };
            
            // Limit to max observations
            let final_observations = if (filtered_buffer.size() > tracked_twap_price.config.max_observations) {
                let start_index = Int.abs(filtered_buffer.size() - tracked_twap_price.config.max_observations);
                let all_observations = Buffer.toArray(filtered_buffer);
                let sliced_observations = Array.tabulate<PriceObservation>(
                    tracked_twap_price.config.max_observations,
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
                return sum / Float.fromInt(sorted_observations.size());
            };
            
            total_weighted_price / total_time_weight;
        };

    };

    public func create_tracked_twap_price(config: TWAPConfig) : TrackedTWAPPrice {
        {
            var spot_price = null;
            var observations = [];
            var twap_cache = null;
            var last_twap_calculation = 0;
            config = config;
        };
    };

};