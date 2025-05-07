import Types "Types";
import Duration "duration/Duration";
import IterUtils "utils/Iter";
import Math "utils/Math";

import Float "mo:base/Float";

import Map "mo:map/Map";

module {

    let EPSILON = 1e-12; // @todo: what value to take?

    type UUID = Types.UUID;
    type Foresight = Types.Foresight;
    type YesNoVote = Types.YesNoVote;
    type Timeline<T> = Types.Timeline<T>;

    type Iter<T> = Map.Iter<T>;

    type Contrib = {
        current: Float;
        cumulated: Float;
    };

    type Accumulator = {
        sum_contribs: Contrib;
        tvl: Nat;
    };
    
    public type InputYield = { 
        earned: Float; // supply_accrued_interests
        apr: Float; // supply_rate
        time_last_update: Nat;
    };

    public type ForesightItem = {
        timestamp: Nat;
        release_date: Nat;
        amount: Nat;
        discernment: Float;
        consent: Float;
        update_foresight: (Foresight, Nat) -> ();
    };

    func init_accumulator() : Accumulator {
        { sum_contribs = { current = 0.0; cumulated = 0.0; }; tvl = 0; };
    };

    public type ContribItem = ForesightItem and { contrib: Contrib };

    public class ForesightUpdater({
        get_yield: () -> InputYield;
    }) {

        public func update_foresights(items: Iter<ForesightItem>) {

            let { earned; apr; time_last_update; } = get_yield();

            // Filter out the inactive items: take only the one which timeline intersects with the time_last_update
            let active_items = IterUtils.filter<ForesightItem>(items, func(item: ForesightItem) : Bool {

                item.timestamp < time_last_update and item.release_date > time_last_update;
            });
            
            // Compute the contribution of each item
            let contrib_items = IterUtils.map<ForesightItem, ContribItem>(active_items, func(item: ForesightItem) : ContribItem {

                var weight = Float.fromInt(item.amount) * item.discernment;
                if (earned < 0.0) {
                    // In case the interests earned by the protocol are negative (due to insolvency),
                    // revert the weights so that the most performing items gets the smallest penalty
                    weight := 1 / weight;
                };
                {   
                    item with contrib = {
                        cumulated = weight * Float.fromInt(time_last_update - item.timestamp);
                        current = weight;
                    };
                };
            });

            // Accumulate the contributions of all items
            let { sum_contribs; tvl; } = IterUtils.fold_left(contrib_items, init_accumulator(), func(acc: Accumulator, contrib_item: ContribItem) : Accumulator {
                {
                    sum_contribs = {
                        cumulated = acc.sum_contribs.cumulated + contrib_item.contrib.cumulated;
                        current = acc.sum_contribs.current + contrib_item.contrib.current;
                    };
                    tvl = acc.tvl + contrib_item.amount;
                };
            });

            // Reset the iterator in order to loop again
            ignore contrib_items.reset();

            for (item in contrib_items) {

                let { cumulated; current; } = item.contrib;

                let remaining_duration = Duration.toAnnual(Duration.getDuration({ from = time_last_update; to = item.release_date; }));
                let lock_duration = Duration.toAnnual(Duration.getDuration({ from = item.timestamp; to = item.release_date; }));
                
                // Actual reward accumulated until now
                let actual_reward = do {
                    // The denominator will always be greater than the nominator, but if both are close to 0, just return 0
                    if(Float.equalWithin(sum_contribs.cumulated, 0.0, EPSILON)) {
                        0.0; 
                    } else {
                        (cumulated / sum_contribs.cumulated) * earned;
                    };
                };
                // Projected reward until the end of the lock
                // This is an approximation because it does not take account that items can be added or removed, but because 
                // it is the same as if as many items were added and removed, we can accept that approximation
                let projected_reward = do {
                    // The denominator will always be greater than the nominator, but if both are close to 0, just return 0
                    if(Float.equalWithin(sum_contribs.current, 0.0, EPSILON)) {
                        0.0;
                    } else {
                        (current / sum_contribs.current) * Math.percentage_to_ratio(apr) * Float.fromInt(tvl) * remaining_duration;
                    };
                };

                let item_apr = Math.ratio_to_percentage((actual_reward + projected_reward) / Float.fromInt(item.amount)) / lock_duration;
                let foresight = {
                    reward = Float.toInt(actual_reward);
                    apr = {
                        current = item_apr;
                        potential = item_apr / item.consent;
                    };
                };
                item.update_foresight(foresight, time_last_update);
            };
        };

    };

};