import Types "Types";
import DebtProcessor "DebtProcessor";
import Timeline "utils/Timeline";
import Incentives "votes/Incentives";

import BTree "mo:stableheapbtreemap/BTree";
import Float "mo:base/Float";
import Debug "mo:base/Debug";

module {

    type Time = Int;
    type LockRegister = Types.LockRegister;
    type ProtocolParameters = Types.ProtocolParameters;

    public class ParticipationDispenser({
        lock_register: LockRegister;
        parameters: ProtocolParameters;
        debt_processor: DebtProcessor.DebtProcessor;
    }) {

        public func dispense(time: Time) {
            
            let period = Float.fromInt(time - lock_register.time_last_dispense);

            if (period < 0) {
                Debug.trap("Cannot dispense participation in the past");
            };

            // Skip if the period is too small
            if (Float.equalWithin(period, 0.0, 1e-6)) {
                return;
            };

            Debug.print("Dispensing participation over period: " # debug_show(period));

            let total_amount = Timeline.current(lock_register.total_amount);

            // Dispense participation over the period
            label dispense for (({id}, ballot) in BTree.entries(lock_register.locks)) {

                let { participation_per_ns; discernment_factor } = parameters;

                let amount = (Float.fromInt(ballot.amount) / Float.fromInt(total_amount)) * period * participation_per_ns;

                // Add the amount to the participation
                let participation = Timeline.current(ballot.rewards).participation + amount;

                // Compute the discernment because the participation changed
                let discernment = Incentives.compute_discernment({
                    participation;
                    dissent = ballot.dissent;
                    consent = Timeline.current(ballot.consent);
                    coefficient = discernment_factor;
                });

                // Update the rewards timeline
                Timeline.add(ballot.rewards, time, { participation; discernment; });
                
                // Transfer the participation right away
                debt_processor.add_debt({ id; amount; time; });
            };

            // Update the time of the last dispense
            lock_register.time_last_dispense := time;
        };
        
    };
};