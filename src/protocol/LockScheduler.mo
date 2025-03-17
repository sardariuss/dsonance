import Types "Types";
import Timeline "utils/Timeline";
import Incentives "votes/Incentives";
import Duration "duration/Duration";
import DebtProcessor "DebtProcessor";

import BTree "mo:stableheapbtreemap/BTree";
import Order "mo:base/Order";
import Text "mo:base/Text";
import Int "mo:base/Int";
import Debug "mo:base/Debug";
import Float "mo:base/Float";
import Option "mo:base/Option";

import Map "mo:map/Map";

module {

    type UUID = Types.UUID;
    type Lock = Types.Lock;
    type YesNoBallot = Types.Ballot<Types.YesNoChoice>;
    type LockRegister = Types.LockRegister;
    type Timeline<T> = Types.Timeline<T>;
    type ProtocolParameters = Types.ProtocolParameters;
    type Foresight = Types.Foresight;
    type VoteType = Types.VoteType;
    type YesNoVote = Types.YesNoVote;
    type DebtRecord = Types.DebtRecord;

    type Map<K, V> = Map.Map<K, V>;
    type Order = Order.Order;

    type LockerState = {
        total_amount: Nat;
        yield: {
            rate: Float;
            cumulated: Float;
            contributions: {
                sum_current: Float;
                sum_cumulated: Float;
            };
        };
    };

    public func compare_locks(a: Lock, b: Lock) : Order {
        switch(Int.compare(a.release_date, b.release_date)){
            case(#less) { #less; };
            case(#greater) { #greater; };
            case(#equal) { Text.compare(a.id, b.id); };
        };
    };

    public class LockScheduler({
        parameters: ProtocolParameters;
        lock_register: LockRegister;
        update_lock_duration: (YesNoBallot, Nat) -> ();
        btc_debt: DebtProcessor.DebtProcessor;
        dsn_debt: DebtProcessor.DebtProcessor;
        votes: Map<UUID, VoteType>;
    }) {

        // TODO: should not be public but it is required for ballot preview
        public func refresh_lock_duration(ballot: YesNoBallot, time: Nat) {
            update_lock_duration(ballot, time);
        };

        // add
        public func add(ballot: YesNoBallot, time: Nat) {
            
            update_lock_duration(ballot, time);
            
            let lock = get_lock(ballot);
            let { locks; total_amount; } = lock_register;

            if (not BTree.has(locks, compare_locks, lock)){
                try_unlock(time);
                ignore BTree.insert(locks, compare_locks, lock, ballot);
                Timeline.insert(total_amount, time, Timeline.current(total_amount) + ballot.amount);
            };
        };

        // update
        public func update(ballot: YesNoBallot, time: Nat) {

            let { locks; } = lock_register;

            // Only update the lock if it is already there
            switch(BTree.delete(locks, compare_locks, get_lock(ballot))) {
                case(null) {};
                case(_) {
                    update_lock_duration(ballot, time);
                    ignore BTree.insert(locks, compare_locks, get_lock(ballot), ballot);
                };
            };
        };

        public func try_unlock(time: Nat) {

            if (time < lock_register.time_last_dispense) {
                Debug.trap("Time shall be greater than the last dispense time");
            };

            if (time == lock_register.time_last_dispense) {
                Debug.print("Ignore try_unlock as time is the same as the last dispense time");
                return;
            };

            let { locks; total_amount; yield; } = lock_register;

            label unlock while (true) {
                switch(BTree.min(locks)) {
                    case(null) { return; };
                    case(?(lock, ballot)) {
                        if (lock.release_date > time) { break unlock; };

                        dispense_rewards({
                            total_locked = Timeline.current(total_amount);
                            time = lock.release_date;
                        });

                        let reward = Timeline.current(ballot.foresight).reward;

                        // Trigger the transfer of the original amount plus the reward
                        btc_debt.increase_debt({ 
                            id = ballot.ballot_id;
                            account = ballot.from;
                            amount = Float.fromInt(ballot.amount + reward);
                            pending = 0.0;
                            time = lock.release_date;
                        });

                        // Remove the lock
                        ignore BTree.delete(locks, compare_locks, lock);

                        // Update the total locked and cumulated yield
                        Timeline.insert(total_amount, lock.release_date, Timeline.current(total_amount) - ballot.amount);
                        yield.cumulated -= Float.fromInt(reward);
                    };
                };
            };

            // Dispense the remaining contribution until now
            dispense_rewards({
                total_locked = Timeline.current(total_amount);
                time;
            });
        };

        public func get_total_locked() : Timeline<Nat> {
            lock_register.total_amount;
        };

        func dispense_rewards({total_locked: Nat; time: Nat; }) {

            let period = time - lock_register.time_last_dispense;

            if (period < 0) {
                Debug.trap("Cannot dispense rewards in the past");
            };

            // Skip if the period is null
            if (period == 0) {
                return;
            };

            Debug.print("Dispensing rewards over period: " # debug_show(period));

            let { contribution_per_ns } = parameters;
            let { total_amount; locks; yield; } = lock_register;

            // Refresh yield cumulated
            yield.cumulated += (Float.fromInt(period) / Float.fromInt(Duration.NS_IN_YEAR)) 
                * Float.fromInt(Timeline.current(total_amount)) * yield.rate;

            // Refresh yield contribution
            yield.contributions.sum_current := 0.0;
            yield.contributions.sum_cumulated := 0.0;

            // Dispense rewards over the period
            for ((lock, ballot) in BTree.entries(locks)) {

                // Compute yield contribution
                let discernment = compute_discernment(ballot);
                yield.contributions.sum_current += Float.fromInt(ballot.amount) * discernment;
                yield.contributions.sum_cumulated += Float.fromInt(ballot.amount) * Float.fromInt(time - ballot.timestamp) * discernment;

                // DSN Contribution
                // TODO: function to compute contribution over period
                let amount = (Float.fromInt(ballot.amount) / Float.fromInt(total_locked)) * Float.fromInt(period) * contribution_per_ns;
                let pending = (Float.fromInt(ballot.amount) / Float.fromInt(total_locked)) * Float.fromInt(lock.release_date - time) * contribution_per_ns;
                
                dispense_lock({ ballot; time; amount; pending; });
            };

            Debug.print("time: " # debug_show(time));
            Debug.print("lock_register.time_last_dispense: " # debug_show(lock_register.time_last_dispense));
            Debug.print("period: " # debug_show(period));
            Debug.print("total_locked: " # debug_show(total_locked));
            Debug.print("yield_contributions.sum_current: " # debug_show(yield.contributions.sum_current));
            Debug.print("yield_contributions.sum_cumulated: " # debug_show(yield.contributions.sum_cumulated));

            for ((lock, ballot) in BTree.entries(locks)){
                // Update ballots BTC reward (foresight); will be transferred when the lock is unlocked
                Timeline.insert(ballot.foresight, time, compute_ballot_foresight(
                    lock,
                    ballot,
                    get_locker_state(),
                    time));
            };

            // Update the last dispense time
            lock_register.time_last_dispense := time;
        };

        public func get_last_dispense() : Nat {
            lock_register.time_last_dispense;
        };

        public func preview_contribution(ballot: YesNoBallot) : DebtRecord {

            let lock = get_lock(ballot);
            
            let { contribution_per_ns } = parameters;
            let total_locked = Timeline.current(lock_register.total_amount);

            {
                earned = 0.0;
                pending = (Float.fromInt(ballot.amount) / Float.fromInt(total_locked + ballot.amount)) * Float.fromInt(lock.release_date - ballot.timestamp) * contribution_per_ns;
            };
        };

        public func preview_foresight(ballot: YesNoBallot) : Foresight {

            let locker_state = {
                total_amount = Timeline.current(lock_register.total_amount) + ballot.amount;
                yield = {
                    rate = lock_register.yield.rate;
                    cumulated = lock_register.yield.cumulated;
                    contributions = {
                        sum_current = lock_register.yield.contributions.sum_current + Float.fromInt(ballot.amount) * compute_discernment(ballot);
                        sum_cumulated = lock_register.yield.contributions.sum_cumulated; // sum_cumulated is null because the ballot has not been added to the lock yet
                    };
                };
            };

            compute_ballot_foresight(get_lock(ballot), ballot, locker_state, ballot.timestamp);
        };

        func dispense_lock({ ballot: YesNoBallot; time: Nat; amount: Float; pending: Float; }) {

            // Split the amount between the ballot and the author of the vote

            dsn_debt.increase_debt({ 
                id = ballot.ballot_id;
                account = ballot.from;
                amount = amount * ( 1.0 - parameters.author_share);
                pending = pending * ( 1.0 - parameters.author_share);
                time;
            });
            
            let vote = get_vote({ vote_id = ballot.vote_id });

            dsn_debt.increase_debt({ 
                id = vote.vote_id;
                account = vote.author;
                amount = amount * parameters.author_share;
                pending = pending * parameters.author_share;
                time;
            });
        };

        func compute_discernment(ballot: YesNoBallot) : Float {
            Incentives.compute_discernment({
                dissent = ballot.dissent;
                consent = Timeline.current(ballot.consent);
                lock_duration = get_lock(ballot).release_date - ballot.timestamp;
                parameters;
            });
        };

        func get_lock(ballot: YesNoBallot) : Lock {
            switch(ballot.lock){
                case(null) { Debug.trap("The ballot does not have a lock"); };
                case(?lock) {
                    { 
                        release_date = lock.release_date;
                        id = ballot.ballot_id; 
                    };
                };
            };
        };

        func get_locker_state() : LockerState {
            {
                total_amount = Timeline.current(lock_register.total_amount);
                yield = {
                    rate = lock_register.yield.rate;
                    cumulated = lock_register.yield.cumulated;
                    contributions = {
                        sum_current = lock_register.yield.contributions.sum_current;
                        sum_cumulated = lock_register.yield.contributions.sum_cumulated;
                    };
                };
            };
        };

        // TODO: one should split that function between the actual and project reward.
        // TODO: should be put outside the class
        func compute_ballot_foresight(lock: Lock, ballot: YesNoBallot, locker_state: LockerState, time: Nat) : Foresight {

            let lock_duration = Float.fromInt(lock.release_date - ballot.timestamp) / Float.fromInt(Duration.NS_IN_YEAR);

            if (ballot.amount == 0 
                or Float.equalWithin(Timeline.current(ballot.consent), 0.0, 1e-9)
                or lock_duration <= 0){
                Debug.print("Ballot amount is 0 or consent is 0 or lock duration is 0, hence return 0 reward");
                return {
                    reward = 0;
                    apr = {
                        current = 0;
                        potential = 0;
                    };
                };
            };

            let { yield; total_amount; } = locker_state;
            let yield_contrib = yield.contributions;

            let discernment = compute_discernment(ballot);
            let ballot_cumulated_yield_contribution = Float.fromInt(ballot.amount) * Float.fromInt(time - ballot.timestamp) * discernment;
            let ballot_current_yield_contribution = Float.fromInt(ballot.amount) * discernment;
            let remaining_duration = Float.fromInt(lock.release_date - time) / Float.fromInt(Duration.NS_IN_YEAR);

            if (yield.cumulated < 0) {
                Debug.trap("Cumulated yield cannot be negative");
            };

            // Actual reward accumulated until now
            let actual_reward = do {
                if(yield_contrib.sum_cumulated <= 0) {
                    0.0; 
                } else {
                    (ballot_cumulated_yield_contribution / yield_contrib.sum_cumulated) * yield.cumulated;
                };
            };
            // Projected reward until the end of the lock
            let projected_reward = do {
                if(yield_contrib.sum_current <= 0) {
                    0.0; 
                } else {
                    (ballot_current_yield_contribution / yield_contrib.sum_current) 
                    * yield.rate * remaining_duration * Float.fromInt(total_amount);
                };
            };
            let reward = Int.abs(Float.toInt(actual_reward + projected_reward));
            
            let apr = (100 * Float.fromInt(reward) / Float.fromInt(ballot.amount)) / lock_duration;
            {
                reward;
                apr = {
                    current = apr;
                    potential = apr / Timeline.current(ballot.consent);
                };
            };
        };

        func get_vote({ vote_id: UUID; }) : YesNoVote {
            switch(Map.get(votes, Map.thash, vote_id)){
                case(null) { Debug.trap("The vote does not exist"); };
                case(?v) { 
                    switch(v){
                        case(#YES_NO(vote)) { vote; };
                    };
                };
            };
        };

    };

};