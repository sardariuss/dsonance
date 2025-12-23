import Types              "../Types";

module {

    type UpdateAggregate<A, C>      = Types.UpdateAggregate<A, C>;
    type ComputeDissent<A, C>       = Types.ComputeDissent<A, C>;
    type ComputeConsent<A, C>       = Types.ComputeConsent<A, C>;
    type PositionAggregatorOutcome<A> = Types.PositionAggregatorOutcome<A>;
    type Decayed = Types.Decayed;
   
    public class PositionAggregator<A, C>({
        update_aggregate: UpdateAggregate<A, C>;
        compute_dissent: ComputeDissent<A, C>;
        compute_consent: ComputeConsent<A, C>;
        compute_consensus: (A) -> Float;
        compute_resistance: (A, C, Float, Nat) -> Float;
        compute_decayed_resistance: (A, C, Float) -> Decayed;
        compute_opposite_worth: (A, C, Float, Nat) -> Float;
        get_opposite_choice: C -> C;
        consensus_direction: (C) -> Int;
    }){
        public func compute_outcome({
            aggregate: A;
            choice: C;
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
            choice: C;
            target_consensus: Float;
            time: Nat;
        }) : Float {
            compute_resistance(aggregate, choice, target_consensus, time);
        };

        public func get_decayed_resistance({
            aggregate: A;
            choice: C;
            target_consensus: Float;
        }) : Decayed {
            compute_decayed_resistance(aggregate, choice, target_consensus);
        };

        public func get_opposite_worth({
            aggregate: A;
            choice: C;
            amount: Float;
            time: Nat;
        }) : Float {
            compute_opposite_worth(aggregate, choice, amount, time);
        };

        public func get_consent({
            aggregate: A;
            choice: C;
            time: Nat;
        }) : Float {
            compute_consent({ aggregate; choice; time; });
        };

        public func get_consensus({
            aggregate: A;
        }) : Float {
            compute_consensus(aggregate);  
        };

        public func get_opposite_choice(choice: C) : C {
            get_opposite_choice(choice);
        };

        public func consensus_direction(choice: C) : Int {
            consensus_direction(choice);
        };

    };

};
