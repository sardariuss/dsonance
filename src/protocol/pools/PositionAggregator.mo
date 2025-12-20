import Types              "../Types";

module {

    type UpdateAggregate<A, B>      = Types.UpdateAggregate<A, B>;
    type ComputeDissent<A, B>       = Types.ComputeDissent<A, B>;
    type ComputeConsent<A, B>       = Types.ComputeConsent<A, B>;
    type PositionAggregatorOutcome<A> = Types.PositionAggregatorOutcome<A>;
    type Decayed = Types.Decayed;
   
    public class PositionAggregator<A, B>({
        update_aggregate: UpdateAggregate<A, B>;
        compute_dissent: ComputeDissent<A, B>;
        compute_consent: ComputeConsent<A, B>;
        compute_resistance: (A, B, Float, Nat) -> Float;
        compute_decayed_resistance: (A, B, Float) -> Decayed;
        compute_opposite_worth: (A, B, Float, Nat) -> Float;
    }){

        public func compute_outcome({
            aggregate: A;
            choice: B;
            amount: Nat;
            time: Nat;
        }) : PositionAggregatorOutcome<A> {

            // Compute the dissent before updating the aggregate
            let dissent = compute_dissent({ aggregate; choice; amount; time; });
            
            // Update the aggregate before computing the consent
            let update = update_aggregate({ aggregate; choice; amount; time; });

            // Compute the consent
            let consent = compute_consent({ aggregate = update; choice; time; });

            {         
                aggregate = { update };
                position = { dissent; consent };
            };
        };

        public func get_resistance({
            aggregate: A;
            choice: B;
            target_consensus: Float;
            time: Nat;
        }) : Float {
            compute_resistance(aggregate, choice, target_consensus, time);
        };

        public func get_decayed_resistance({
            aggregate: A;
            choice: B;
            target_consensus: Float;
        }) : Decayed {
            compute_decayed_resistance(aggregate, choice, target_consensus);
        };

        public func get_opposite_worth({
            aggregate: A;
            choice: B;
            amount: Float;
            time: Nat;
        }) : Float {
            compute_opposite_worth(aggregate, choice, amount, time);
        };

        public func get_consent({
            aggregate: A;
            choice: B;
            time: Nat;
        }) : Float {
            compute_consent({ aggregate; choice; time; });
        };

    };

};
