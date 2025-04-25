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

    type BorrowError = {
        #InsufficientBorrowable: {
            max_borrowable: Nat;
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

        public func get_available_supply() : Int {
            state.total_supply - state.total_borrowed;
        };

        public func update_total_supply({ new_total_supply: Nat; time: Nat; }) {
            accrue_yield(time);
            state.total_supply := new_total_supply;
        };

        public func borrow({ amount: Nat; time: Nat; }) : Result<(), BorrowError> {
            
            accrue_yield(time);

            let max_borrowable = get_max_borrowable();

            if (amount > max_borrowable) {
                return #err(#InsufficientBorrowable({ max_borrowable }));
            };

            state.total_borrowed += amount;
            #ok;
        };

        public func get_max_borrowable() : Nat {
            
            let max_borrowable_float = (Float.fromInt(state.total_supply) * (1.0 - state.reserve_factor) - Float.fromInt(state.total_borrowed));

            if (max_borrowable_float <= 0.0) {
                0;
            } else {
                Int.abs(Float.toInt(max_borrowable_float));
            };
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