import Types "Types";
import Lender "Lender";
import Timeline "utils/Timeline";
import Duration "duration/Duration";
import MapUtils "utils/Map";

import Text "mo:base/Text";
import Int "mo:base/Int";
import Debug "mo:base/Debug";
import Float "mo:base/Float";

import Map "mo:map/Map";

module {

    type UUID = Types.UUID;
    type YesNoBallot = Types.Ballot<Types.YesNoChoice>;
    type Foresight = Types.Foresight;
    type YesNoVote = Types.YesNoVote;
    
    type LenderInfo = Lender.LenderInfo;
    type Map<K, V> = Map.Map<K, V>;

    type Contrib = {
        current: Float;
        cumulated: Float;
    };

    public class ForesightCalculator(
        ballots: Map<UUID, YesNoBallot>,
        compute_discernment: (YesNoBallot) -> Float,
    ) {

        public func update_foresights(
            lender_info: LenderInfo,
            time: Nat,
        ) {
            let foresights = compute_foresights(ballots, lender_info, time);
            for ((id, ballot) in Map.entries(ballots)){
                Timeline.insert(ballot.foresight, time, MapUtils.getOrTrap(foresights, Map.thash, id));
            };
        };

        public func compute_foresights(
            ballots: Map<UUID, YesNoBallot>,
            lender_info: LenderInfo,
            time: Nat,
        ) : Map<UUID, Foresight> {
            
            let ballot_contribs = Map.map<UUID, YesNoBallot, Contrib>(ballots, Map.thash, func(id: UUID, ballot: YesNoBallot) : Contrib {
                let weight = Float.fromInt(ballot.amount) * compute_discernment(ballot);
                {
                    cumulated = weight * Float.fromInt(time - ballot.timestamp);
                    current = weight;
                };
            });

            let sum_contribs = MapUtils.fold_left(ballot_contribs, { current = 0.0; cumulated = 0.0; }, func(acc: Contrib, contrib: Contrib) : Contrib {
                {
                    cumulated = acc.cumulated + contrib.cumulated;
                    current = acc.current + contrib.current;
                };
            });

            Map.map<UUID, YesNoBallot, Foresight>(ballots, Map.thash, func(id: Text, ballot: YesNoBallot) : Foresight {

                let release_date = switch(ballot.lock){
                    case(null) { Debug.trap("The ballot does not have a lock"); };
                    case(?lock) { lock.release_date; };
                };
                let remaining_duration = Float.fromInt(release_date - time) / Float.fromInt(Duration.NS_IN_YEAR);
                let lock_duration = Float.fromInt(release_date - ballot.timestamp) / Float.fromInt(Duration.NS_IN_YEAR);
                let ballot_contrib = MapUtils.getOrTrap(ballot_contribs, Map.thash, id);

                // Actual reward accumulated until now
                let actual_reward = do {
                    if(sum_contribs.cumulated <= 0) {
                        0.0; 
                    } else {
                        (ballot_contrib.cumulated / sum_contribs.cumulated) * lender_info.interest.earned;
                    };
                };
                // Projected reward until the end of the lock
                // This is an approximation because:
                //  - [TODO: fix] the yield rate can change over time and not reflect the current rate (i.e. yield_cumulated)
                //  - [accepted] it does not take account that ballots can be added or removed, but it is the same as if as many ballots
                //    are added as removed
                let projected_reward = do {
                    if(sum_contribs.current <= 0) {
                        0.0; 
                    } else {
                        (ballot_contrib.current / sum_contribs.current) * lender_info.rate_per_year * Float.fromInt(lender_info.tvl) * remaining_duration;
                    };
                };

                let reward = Int.abs(Float.toInt(actual_reward + projected_reward));
                
                let apr = (100 * Float.fromInt(reward) / Float.fromInt(ballot.amount)) / (lock_duration);
                {
                    reward;
                    apr = {
                        current = apr;
                        potential = apr / Timeline.current(ballot.consent);
                    };
                };
            });
        };

    };

};