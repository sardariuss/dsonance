import Types "Types";
import Duration "duration/Duration";
import Math "utils/Math";
import InterestRateCurve "InterestRateCurve";

import Float "mo:base/Float";
import Debug "mo:base/Debug";
import Int "mo:base/Int"; 
import Result "mo:base/Result"; 

module {

    type Result<Ok, Err> = Result.Result<Ok, Err>;

    type ClaimInterestError = {
        #InsufficientAccruedInterest: {
            amount: Float;
        };
    };

    type YieldState = {
        var total_supply: Nat; // Renamed from tvl
        var total_borrowed: Nat;     // Amount currently borrowed
        var reserve_factor: Float; // Portion of supply reserved (0.0 to 1.0, e.g., 0.1 for 10%)
        interest: {
            var accrued: Float; // Interest accrued by suppliers (in underlying asset)
            var time_last_update: Nat;
        };
    };

    public class Yielder({
        state: YieldState;
        interest_rate_curve: InterestRateCurve.InterestRateCurve;
    }) {

        public func get_state() : YieldState {
            state;
        };

        // Function to calculate and return the available supply (liquidity)
        public func get_available_supply() : Nat {
            // Calculate available supply: total_supply - total_borrowed
            // Ensure result is not negative (shouldn't happen with current logic, but safe check)
            if (state.total_supply >= state.total_borrowed) {
                state.total_supply - state.total_borrowed;
            } else {
                // This case indicates an inconsistency, as borrowing shouldn't exceed supply.
                // Returning 0 is a safe default. Consider logging or trapping if this occurs.
                // Debug.print("Warning: Total borrowed exceeds total supply in get_available_supply");
                0;
            };
        };

        // Renamed from update_tvl
        public func update_total_supply({ new_total_supply: Nat; time: Nat; }) {
            accrue_yield(time);
            state.total_supply := new_total_supply;
        };

        // New function to update the borrowed amount
        public func update_total_borrowed({ new_total_borrowed: Nat; time: Nat; }) {
            accrue_yield(time);

            // Calculate the maximum borrowable amount based on reserve factor
            // borrowable = total_supply * (1 - reserve_factor)
            let max_borrowable = do {
                let max_borrowable_float = Float.fromInt(state.total_supply) * (1.0 - state.reserve_factor);
                if (max_borrowable_float <= 0.0) {
                    0;
                } else {
                    Int.abs(Float.toInt(max_borrowable_float));
                };
            };

            // Trap if new_total_borrowed exceeds max_borrowable
            if (new_total_borrowed > max_borrowable) {
                Debug.trap("Borrow amount exceeds reserve limit");
            };

            state.total_borrowed := new_total_borrowed;
        };

        public func claim_accrued_interest({ amount: Nat; time: Nat; }) : Result<(), ClaimInterestError> {
            accrue_yield(time);
            
            let diff = state.interest.accrued - Float.fromInt(amount);
            var result : Result<(), ClaimInterestError> = #ok;
            if (diff < 0) {
                result := #err(#InsufficientAccruedInterest({ amount = state.interest.accrued }));
                state.interest.accrued := 0;
            } else {
                state.interest.accrued := diff;
            };
            result;
        };

        // Renamed from accumulate_yield
        func accrue_yield(time: Nat) {
            
            // If the time is before the last update
            if (time < state.interest.time_last_update) {
                Debug.trap("Cannot accrue yield: time is before last update");
            };

            // Calculate utilization ratio
            let utilization = do {
                if (state.total_supply == 0) {
                    // If total supply is 0, utilization is technically undefined or 0.
                    0.0;
                } else {
                    // Ensure float division using state.total_borrowed
                    Float.fromInt(state.total_borrowed) / Float.fromInt(state.total_supply);
                };
            };

            // Clamp utilization between 0.0 and 1.0 as a safeguard
            let clamped_utilization = Float.max(0.0, Float.min(1.0, utilization));

            // Get the current interest rate from the curve
            let current_rate_percent = interest_rate_curve.get_current_rate(clamped_utilization);
            let current_rate_ratio = Math.percentageToRatio(current_rate_percent); // Convert e.g. 5.0 to 0.05

            // Calculate the time period in years
            let annual_period = Duration.toAnnual(Duration.getDuration({ from = state.interest.time_last_update; to = time; }));

            // Calculate interest accrued = borrowed_amount * rate * time_period
            // Use state.total_borrowed here
            state.interest.accrued += Float.fromInt(state.total_borrowed) * current_rate_ratio * annual_period;
            state.interest.time_last_update := time;
        };

    };

};