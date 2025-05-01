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
            available_borrow_amount: Nat;
        };
    };

    type RepayError = {
        #RepayAmountExceedsBorrowed;
    };

    type YieldState = {
        var total_deposit: Nat; // Renamed from tvl
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

        public func get_available_liquidity() : Int {
            state.total_deposit - state.total_borrowed;
        };

        public func update_total_deposit({ new_total_deposit: Nat; time: Nat; }) {
            accrue_yield(time);
            // TODO: Add check: Ensure new_total_deposit * (1 - reserve_factor) >= total_borrowed.
            // If violated, either reject the update or trigger liquidation logic (future).
            state.total_deposit := new_total_deposit;
        };

        public func borrow({ amount: Nat; time: Nat; }) : Result<(), BorrowError> {
            
            accrue_yield(time);

            let available_borrow_amount = get_available_borrow_amount();

            if (amount > available_borrow_amount) {
                return #err(#InsufficientBorrowable({ available_borrow_amount }));
            };

            state.total_borrowed += amount;
            #ok;
        };

        public func repay({ amount: Nat; time: Nat; }) : Result<(), RepayError> {
            accrue_yield(time);

            if (amount > state.total_borrowed) {
                return #err(#RepayAmountExceedsBorrowed);
            };

            state.total_borrowed -= amount;
            #ok;
        };

        public func get_available_borrow_amount() : Nat {
            
            let available_float = (Float.fromInt(state.total_deposit) * (1.0 - state.reserve_factor) - Float.fromInt(state.total_borrowed));

            if (available_float <= 0.0) {
                0;
            } else {
                Int.abs(Float.toInt(available_float));
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
                if (state.total_deposit == 0) {
                    // If total deposit is 0, utilization is technically undefined or 0.
                    0.0;
                } else {
                    // Ensure float division using state.total_borrowed
                    Float.fromInt(state.total_borrowed) / Float.fromInt(state.total_deposit);
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