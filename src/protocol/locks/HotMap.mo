import Float "mo:base/Float";
import Iter  "mo:base/Iter";
import Debug "mo:base/Debug";

module {

    type Iter<T> = Iter.Iter<T>;

    type HotItem = {
        amount: Nat;
        timestamp: Nat;
        decay: Float;
        var hotness: Float;
    };

    // Creates a new elem with the given amount and timestamp
    // Deduce the decay from the given timestamp
    // Deduce the hotness of the elem from the previous elems
    // Update the hotness of the previous elems
    // The hotness of an elem is the amount of that elem, plus the sum of the previous elem
    // amounts weighted by their growth, plus the sum of the next elem amounts weighted
    // by their decay:
    //
    //  hotness_i = amount_i
    //            + (growth_0  * amount_0   + ... + growth_i-1 * amount_i-1) / growth_i
    //            + (decay_i+1 * amount_i+1 + ... + decay_n    * amount_n  ) / decay_i
    //
    //                 elem 0                elem i                   elem n
    //                       
    //                    |                    |                        |
    //   growth           |                    |                        |          ·
    //     ↑              |                    |                        |        ···
    //       → time       |                    |                        ↓    ·······
    //                    |                    |                     ···············
    //                    ↓                    ↓     ·······························
    //               ·······························································
    //
    //                    |                    |                        |           
    //               ·    |                    |                        |
    //   decay       ···  ↓                    |                        |
    //     ↑         ·······                   |                        |
    //       → time  ···············           ↓                        |
    //               ·······························                    ↓
    //               ·······························································
    //
    // Since we use the same rate for growth and decay, we can use the same weight for 
    // weighting the previous elems and the next elems. The hotness can be simplified to:
    //
    //  hotness_i = amount_i
    //            + (decay_0 / decay_i  ) * amount_0   + ... + (decay_i-1 / decay_i) * amount_i-1
    //            + (decay_i / decay_i+1) * amount_i+1 + ... + (decay_i  / decay_n ) * amount_n
    public func add_new({
        iter: Iter<HotItem>;
        elem: HotItem;
    }) {

        if(elem.hotness > 0.0) {
            Debug.trap("The hotness of the new elem should be 0.0");
        };

        // Init with the ballot amount
        elem.hotness := Float.fromInt(elem.amount);

        // Iterate over the previous elems
        for (prev_elem in iter) {

            // Compute the weight between the two elems
            let weight = prev_elem.decay / elem.decay;

            // Update the hotness of the new elem
            elem.hotness += Float.fromInt(prev_elem.amount) * weight;

            // Update the hotness of the previous elem
            prev_elem.hotness += Float.fromInt(elem.amount) * weight;
        };
    };

};
