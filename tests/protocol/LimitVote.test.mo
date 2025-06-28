import Float "mo:base/Float";
import Debug "mo:base/Debug";

import Types "../../src/protocol/Types";

import { test; suite; } "mo:test";

import { verify; Testify; } = "../utils/Testify";

suite("Limit vote", func(){

    test("From chatGPT", func () {

        let MIN_DISSENT = 1e-3;
        let MAX_ITERATIONS = 100;

        func compute_dissent({
            steepness: Float;
            choice: Types.YesNoChoice;
            amount: Float;
            total_yes: Float;
            total_no: Float;
        }) : Float {

            let { same; opposit; } = switch (choice) {
                case (#YES) { { same = total_yes; opposit = total_no; }; };
                case (#NO) { { same = total_no; opposit = total_yes; }; };
            };

            let x = amount;
            let p = steepness;
            let total = same + opposit;

            if (Float.abs(1.0 - p) < 1e-8) {
                Debug.trap("steepness (p) = 1 is not supported due to division by zero");
            };

            if (x <= 0) return 0;

            // Guard: p = 1 leads to division by zero
            if (Float.abs(1.0 - p) < 1e-8) {
                Debug.trap("steepness (p) = 1 is not supported due to division by zero");
            };

            let numerator = Float.pow(opposit, p);
            let denomFactor = 1.0 - p;
            let upper = Float.pow(total + x, 1.0 - p);
            let lower = Float.pow(total, 1.0 - p);
            let integral = numerator / denomFactor * (upper - lower);
            integral / x;
        };

        let amount_searched = 180000000.0;

        let input = {
            total_yes = 200.0;
            total_no = 300.0;
            steepness = 0.55;
            choice = #YES;
            amount = amount_searched;
        };
        let targetDissent = compute_dissent(input);
        Debug.print("Target dissent for input " # debug_show(input) # ": " # debug_show(targetDissent));

        func find_amount_for_dissent(dissent: Float) : Float {
            var target = dissent;

            // Compute dissent at amount = 1 to define maximum possible dissent
            let maximumDissent = compute_dissent({ input with amount = 1.0 });
            if (target > maximumDissent) {
                Debug.trap("The target dissent is too high, maximum is " # debug_show(maximumDissent));
            };

            // Clamp low dissent to MIN_DISSENT to avoid flattening edge cases
            if (target < MIN_DISSENT) {
                Debug.print("Target dissent too low, clamping to " # debug_show(MIN_DISSENT));
                target := MIN_DISSENT;
            };

            // Establish search bounds
            var low = 1.0;
            var high = 1e3;
            var lastDissent = compute_dissent({ input with amount = high });

            var expandIter = 0;
            // NOTE: Works because the dissent function is strictly decreasing with respect to amount
            while (lastDissent > target and expandIter < MAX_ITERATIONS) {
                low := high;
                high := high * 1e3;
                lastDissent := compute_dissent({ input with amount = high });
                expandIter += 1;
            };
            if (expandIter == MAX_ITERATIONS) {
                Debug.trap("Failed to find upper bound for amount in " # debug_show(MAX_ITERATIONS) # " iterations");
            };

            Debug.print("Searching for amount in range [" # debug_show(low) # ", " # debug_show(high) # "]");

            let tolerance : Float = 1e-3;
            var mid : Float = 0;
            var searchIter = 0;

            while (high - low > tolerance and searchIter < MAX_ITERATIONS) {
                mid := (low + high) / 2.0;
                let value = compute_dissent({ input with amount = mid });
                if (value > target) {
                    low := mid;
                } else {
                    high := mid;
                };
                searchIter += 1;
            };

            if (searchIter == MAX_ITERATIONS) {
                Debug.print("Warning: max binary search iterations reached. Result may be approximate.");
            };

            return (low + high) / 2.0;
        };

        verify<Float>(
            find_amount_for_dissent(targetDissent),
            amount_searched,
            Testify.float.equalEpsilon3
        );
    });

});