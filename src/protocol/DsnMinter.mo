import Types "Types";
import Duration "duration/Duration";

import Debug "mo:base/Debug";
import Float "mo:base/Float";
import Int "mo:base/Int";

module {

    type DsnMinterParameters = Types.DsnMinterParameters;
    type ICRC1 = Types.ICRC1;
    type ICRC2 = Types.ICRC2;
    type Duration = Types.Duration;

    public class DsnMinter({
        parameters: DsnMinterParameters;
        _dsn_ledger: ICRC1 and ICRC2;
        last_mint_timestamp: { var value: Nat; };
    }) {

        public func mint(current_time: Nat) {
            let time_diff = do {
                let diff : Int = current_time - last_mint_timestamp.value;
                if (diff < 0) {
                    Debug.trap("Cannot mint with current time before last mint timestamp");
                };
                if (diff == 0) {
                    Debug.print("No time has passed since the last mint.");
                    return;
                };
                Int.abs(diff);
            };

            // Convert time_diff from nanoseconds to seconds for the formula
            // This conversion is crucial for floating point precision in exponential calculations.
            // Using nanoseconds directly would create extremely small k values (e.g., 8e-15 for 1-day half-life)
            // which can lose precision in e^(-kt). Converting to seconds keeps values numerically stable.
            let time_diff_seconds = Float.fromInt(time_diff) / Float.fromInt(Duration.NS_IN_SECOND);
            
            // Calculate k = ln(2) / T_h where T_h is half_life in seconds
            let half_life_ns = Duration.toTime(parameters.half_life);
            let half_life_seconds = Float.fromInt(half_life_ns) / Float.fromInt(Duration.NS_IN_SECOND);
            let k = Float.log(2.0) / half_life_seconds;
            
            // Calculate emission using formula: E_0 * (1 - e^(-kt))
            let initial_emission_rate = Float.fromInt(parameters.initial_emission_rate);
            let amount_to_mint = initial_emission_rate * (1.0 - Float.exp(-k * time_diff_seconds));
            
            Debug.print("DsnMinter: Amount to mint = " # debug_show(amount_to_mint) # " DSN tokens");
            Debug.print("DsnMinter: Time difference = " # debug_show(time_diff_seconds) # " seconds");
            Debug.print("DsnMinter: k = " # debug_show(k));
            Debug.print("DsnMinter: Half-life = " # debug_show(half_life_seconds) # " seconds");
            
            // Update the last mint timestamp
            last_mint_timestamp.value := current_time;
        };

    };

};