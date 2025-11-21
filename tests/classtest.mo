import Map "mo:map/Map";
import Float "mo:base/Float";

module {

    type StableType = {
        var raw_amount: Nat;
        pos_index: Float;
    };
    
    type Indexer = {
        get_current_index: () -> Float;
    };

    type Dependencie2 = {
        // some methods
    };

    type Dependencie3 = {
        // some methods
    };

    public class ActualClass(
        stable_type: StableType, 
        indexer: Indexer,
        dep2: Dependencie2,
        dep3: Dependencie3
    ) {
        
        public func getAmount() : Float {
            Float.fromInt(stable_type.raw_amount) * indexer.get_current_index() / stable_type.pos_index;
        };

        public func removeAmount(_: Float) : () {
            // some logic that updates stable_type.amount using indexer, dep2, dep3, etc..
        };
    };

    // Goal is to have a map of StableType in stable memory, but in runtime have a map of ActualClass

    public class ClassFactory({
        indexer: Indexer;
        dep2: Dependencie2;
        dep3: Dependencie3;
    }){ 
        public func create(stable_type: StableType) : ActualClass {
            ActualClass(stable_type, indexer, dep2, dep3);
        };
    };

    public class Mapper<K, V, C>(
        stable_map: Map.Map<K, V>,
        hash_utils: Map.HashUtils<K>,
        create: V -> C,
    ) {

        public func get(key: K) : ?C {
            switch(Map.get(stable_map, hash_utils, key)){
                case(?stable_value) {
                    ?create(stable_value);
                };
                case(null) {
                    null;
                };
            };
        };

        // do the same with other Map methods
    };

    public func example_usage() : () {
        let stable_map: Map.Map<Text, StableType> = Map.new<Text, StableType>();
        let factory = ClassFactory({
            indexer = {
                get_current_index = func() : Float { 1.0 };
            };
            dep2 = {
                // ...
            };
            dep3 = {
                // ...
            };
        });

        let mapper = Mapper<Text, StableType, ActualClass>(
            stable_map,
            Map.thash,
            factory.create,
        );

        let maybe_class = mapper.get("example_key");
        switch(maybe_class){
            case(?class_instance) {
                let amount = class_instance.getAmount();
                // do something with amount
            };
            case(null) {
                // handle missing key
            };
        };
    };
    
};