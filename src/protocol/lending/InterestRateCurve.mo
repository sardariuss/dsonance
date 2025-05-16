import Float "mo:base/Float";
import Debug "mo:base/Debug";

import LendingTypes "Types";

module {

    type CurvePoint = LendingTypes.CurvePoint;

    public class InterestRateCurve(curve: [CurvePoint]) {

        public func get_apr(utilization: Float) : Float {

            if (utilization < 0.0 or utilization > 1.0){
                Debug.trap("Utilization must be between 0.0 and 1.0");
            };

            // Ensure curve is sorted by utilization (caller responsibility or sort here)
            // Handle edge cases: empty curve, utilization outside defined range
            if (curve.size() == 0) { return 0.0; }; // Default rate if curve is empty

            var i = 0;
            while (i < curve.size() and utilization > curve[i].utilization) {
                i += 1;
            };

            if (i == 0) {
                // Utilization is below or at the first point's utilization
                curve[0].percentage_rate;
            } else if (i == curve.size()) {
                // Utilization is above the last point's utilization
                curve[curve.size() - 1].percentage_rate;
            } else {
                // Linear interpolation between points i-1 and i
                let p1 = curve[i - 1];
                let p2 = curve[i];
                // Avoid division by zero if utilization points are identical
                if (p1.utilization == p2.utilization) {
                    return p1.percentage_rate;
                };
                let utilization_diff = p2.utilization - p1.utilization;
                let rate_diff = p2.percentage_rate - p1.percentage_rate;
                let slope = rate_diff / utilization_diff;
                // Rate = base_rate + slope * (current_utilization - base_utilization)
                p1.percentage_rate + slope * (utilization - p1.utilization);
            };
        };

    };

};