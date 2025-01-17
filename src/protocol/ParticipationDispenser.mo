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
    type MintingParameters = Types.MintingParameters;
    type ProtocolInfo = Types.ProtocolInfo;

    public class ParticipationDispenser({
        lock_register: LockRegister;
        parameters: MintingParameters;
        debt_processor: DebtProcessor.DebtProcessor;
    }) {

        public func dispense(time: Time) {
            
            let period = Float.fromInt(time - parameters.time_last_dispense);

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
            parameters.time_last_dispense := time;
        };

        public func get_info() : ProtocolInfo {
            {
                participation_per_ns = parameters.participation_per_ns;
                time_last_dispense = parameters.time_last_dispense;
                resonance_minted = parameters.amount_minted;
                ck_btc_locked = lock_register.total_amount;
                discernment_factor = parameters.discernment_factor;
            };
        };
        
    };
};