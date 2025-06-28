import Float "mo:base/Float";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Debug "mo:base/Debug";

import Types "../../src/protocol/Types";

import { test; suite; } "mo:test";

import { verify; Testify; } = "../utils/Testify";

suite("Limit vote", func(){

    test("From chatGPT", func(){

        func compute_dissent({
            steepness: Float;
            choice: Types.YesNoChoice;
            amount: Float;
            total_yes: Float; 
            total_no: Float;
        }) : Float {

            let { same; opposit; } = switch(choice){
                case(#YES) { { same = total_yes; opposit = total_no; }; };
                case(#NO) { { same = total_no; opposit = total_yes; }; };
            };

            let x = amount;
            let p = steepness;
            let total = same + opposit;

            if (amount <= 0) return 0;

            let numerator = Float.pow(opposit, p);
            let denomFactor = 1.0 - p;
            let upper = Float.pow(total + x, 1.0 - p);
            let lower = Float.pow(total, 1.0 - p);
            let integral = numerator / denomFactor * (upper - lower);
            integral / x;
        };

        let amount_searched = 180000000.0;

        // Example input
        let input = {
            total_yes = 200.0;
            total_no = 300.0;
            steepness = 0.55;
            choice = #YES;
            amount = amount_searched;
        };
        let targetDissent = compute_dissent(input);
        Debug.print("Target dissent for input " # debug_show(input) # ": " # Float.toText(targetDissent));

        // Find x such that compute_dissent(x) ≈ targetDissent
        func find_amount_for_dissent(dissent: Float) : Float {

            var target = dissent;

            // Todo: low amount will always be 1, so compute dissent for 1 and verify given dissent is lower than that
            //       high amount needs to bounded, the minimum dissent should be close enough to 0, like 1e-6, need to compute the 
            //       amount corresponding to that dissent and use it as high bound
            
            let maximumDissent = compute_dissent({ input with amount = 1.0; });
            if (target > maximumDissent) {
                Debug.trap("The target dissent is too high, maximum dissent is " # Float.toText(maximumDissent));
            };

            let minimumDissent = 1e-3;
            if (target < minimumDissent) {
                Debug.print("The target dissent is too low, use " # Float.toText(minimumDissent) # " as target instead.");
                target := minimumDissent;
            };

            // Find the limit range to start the binary search
            // Watchout, this assumes that the dissent is a monotonically decreasing function of the amount
            var low = 1.0;
            var high = 1e3;
            var lastDissent = compute_dissent({ input with amount = high; });
            while (lastDissent > target) {
                low := high;
                high := high * 1e3;
                lastDissent := compute_dissent({ input with amount = high; });
            };

            Debug.print("Searching for amount in range [" # Float.toText(low) # ", " # Float.toText(high) # "]");

            let tolerance : Float = 1e-3;
            var mid : Float = 0;

            while (high - low > tolerance) {
                mid := (low + high) / 2.0;
                let value = compute_dissent({ input with amount = mid; });
                if (value > dissent) {
                    low := mid;
                } else {
                    high := mid;
                };
            };

            return (low + high) / 2.0;
        };

        verify<Float>(find_amount_for_dissent(targetDissent), amount_searched, Testify.float.equalEpsilon3);

    });
});