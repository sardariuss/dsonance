import Types "Types";
import Duration "duration/Duration";
import IterUtils "utils/Iter";

import Int "mo:base/Int";
import Float "mo:base/Float";

import Map "mo:map/Map";

module {

    type UUID = Types.UUID;
    type Foresight = Types.Foresight;
    type YesNoVote = Types.YesNoVote;
    type Timeline<T> = Types.Timeline<T>;

    type Iter<T> = Map.Iter<T>;

    type Contrib = {
        current: Float;
        cumulated: Float;
    };
    
    public type InputYield = { 
        earned: Float;
        apr: Float;
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

    public type ContribItem = ForesightItem and Contrib;

    public class ForesightUpdater({
        get_yield: () -> InputYield;
    }) {

        public func update_foresights(items: Iter<ForesightItem>) {

            let { earned; apr; time_last_update; } = get_yield();
            
            let item_contribs = IterUtils.map<ForesightItem, ContribItem>(items, func(item: ForesightItem) : ContribItem {
                let weight = Float.fromInt(item.amount) * item.discernment;
                {
                    item with
                    cumulated = weight * Float.fromInt(time_last_update - item.timestamp);
                    current = weight;
                };
            });

            // @todo
            type Temp = {
                sum_contribs: Contrib;
                tvl: Nat;
            };

            let { sum_contribs; tvl; } = IterUtils.fold_left(item_contribs, { sum_contribs = { current = 0.0; cumulated = 0.0; }; tvl = 0; }, func(acc: Temp, item_contrib: ContribItem) : Temp {
                {
                    sum_contribs = {
                        cumulated = acc.sum_contribs.cumulated + item_contrib.cumulated;
                        current = acc.sum_contribs.current + item_contrib.current;
                    };
                    tvl = acc.tvl + item_contrib.amount;
                };
            });

            ignore item_contribs.reset();

            for (item in item_contribs) {

                let remaining_duration = Duration.toAnnual(Duration.getDuration({ from = time_last_update; to = item.release_date; }));
                let lock_duration = Duration.toAnnual(Duration.getDuration({ from = item.timestamp; to = item.release_date; }));
                
                // Actual reward accumulated until now
                let actual_reward = do {
                    if(sum_contribs.cumulated <= 0) {
                        0.0; 
                    } else {
                        (item.cumulated / sum_contribs.cumulated) * earned;
                    };
                };
                // Projected reward until the end of the lock
                // This is an approximation because:
                //  - [TODO: fix] the yield rate can change over time and not reflect the current rate (i.e. yield_cumulated)
                //  - [accepted] it does not take account that items can be added or removed, but it is the same as if as many items
                //    are added as removed
                let projected_reward = do {
                    if(sum_contribs.current <= 0) {
                        0.0; 
                    } else {
                        (item.current / sum_contribs.current) * apr / 100 * Float.fromInt(tvl) * remaining_duration;
                    };
                };

                let reward = actual_reward + projected_reward;
                let item_apr = (100 * reward / Float.fromInt(item.amount)) / lock_duration;
                let foresight = {
                    reward = Int.abs(Float.toInt(reward));
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