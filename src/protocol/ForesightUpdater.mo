import Types "Types";
import Duration "duration/Duration";
import IterUtils "utils/Iter";
import Math "utils/Math";

import Float "mo:base/Float";

import Map "mo:map/Map";

module {

    let EPSILON = 1e-12; // TODO: review if this epsilon is appropriate for the use case

    type UUID = Types.UUID;
    type Foresight = Types.Foresight;
    type YesNoVote = Types.YesNoVote;
    type Timeline<T> = Types.Timeline<T>;
    type SIndexerState = Types.SIndexerState;

    type Iter<T> = Map.Iter<T>;

    type Contrib = {
        current: Float;
        cumulated: Float;
    };

    type Accumulator = {
        sum_contribs: Contrib;
        tvl: Nat;
    };
    
    public type SupplyInfo = { 
        accrued_interests: Float;
        interests_rate: Float;
        last_update_timestamp: Nat;
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
        initial_supply_info: SupplyInfo;
        get_items: () -> Iter<ForesightItem>;
    }) {

        var supply_info = initial_supply_info;

        public func set_supply_info(new_supply_info: SupplyInfo) {
            supply_info := new_supply_info;
            update_foresights();
        };

        public func update_foresights() {

            let { accrued_interests; interests_rate; last_update_timestamp; } = supply_info;

            // Filter out the inactive items: take only the one which timeline intersects with the last_update_timestamp
            let active_items = IterUtils.filter<ForesightItem>(get_items(), func(item: ForesightItem) : Bool {
                item.timestamp <= last_update_timestamp and item.release_date >= last_update_timestamp;
            });
            
            // Compute the contribution of each item
            let contrib_items = IterUtils.map<ForesightItem, ContribItem>(active_items, func(item: ForesightItem) : ContribItem {

                var weight = Float.fromInt(item.amount) * item.discernment;
                if (accrued_interests < 0.0) {
                    // In case the interests earned by the protocol are negative (due to insolvency),
                    // revert the weights so that the most performing items gets the smallest penalty
                    weight := 1 / weight;
                };
                {   
                    item with contrib = {
                        cumulated = weight * Float.fromInt(last_update_timestamp - item.timestamp);
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

                let remaining_duration = Duration.toAnnual(Duration.getDuration({ from = last_update_timestamp; to = item.release_date; }));
                let lock_duration = Duration.toAnnual(Duration.getDuration({ from = item.timestamp; to = item.release_date; }));
                
                
                let share = do {
                    // The denominator will always be greater than the nominator, but if both are close to 0, just return 0
                    if(Float.equalWithin(sum_contribs.cumulated, 0.0, EPSILON)) {
                        0.0; 
                    } else {
                        (cumulated / sum_contribs.cumulated);
                    };
                };
                // Actual reward accumulated until now
                let actual_reward = share * accrued_interests;

                // Projected reward until the end of the lock
                // This is an approximation because it does not take account that items can be added or removed, but because 
                // it is the same as if as many items were added and removed, we can accept that approximation
                let projected_reward = do {
                    // The denominator will always be greater than the nominator, but if both are close to 0, just return 0
                    if(Float.equalWithin(sum_contribs.current, 0.0, EPSILON)) {
                        0.0;
                    } else {
                        (current / sum_contribs.current) * interests_rate * Float.fromInt(tvl) * remaining_duration;
                    };
                };

                let item_apr = (actual_reward + projected_reward) / Float.fromInt(item.amount) / lock_duration;
                let foresight = {
                    share;
                    reward = Float.toInt(actual_reward);
                    apr = {
                        current = item_apr;
                        potential = item_apr / item.consent;
                    };
                };
                item.update_foresight(foresight, last_update_timestamp);
            };
        };

    };

};