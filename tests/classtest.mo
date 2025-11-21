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
    public func map<K, V, C>(
        stable_map: Map.Map<K, V>,
        utils: Map.HashUtils<K>,
        to_class: V -> C,
        new: C -> V,
    ) : {
        get: K -> ?C;
        put: (K, C) -> ?C;
    } = object {
    
        public func get(key: K) : ?C {
            do ?{ to_class(Map.get(stable_map, utils, key)!); };
        };

        public func put(key: K, class_instance: C) : ?C {
            do ?{ to_class(Map.put(stable_map, utils, key, new(class_instance))!); };
        };
    };

    public func example_usage() : () {
        let stable_map: Map.Map<Text, StableType> = Map.new<Text, StableType>();
        let sharedIndexer = {
            get_current_index = func() : Float { Float.fromInt(100); };
        };
        let sharedDep2 = {};
        let sharedDep3 = {};

        let actualMap = map(
            stable_map,
            Map.thash,
            func(stable_type) = ActualClass(stable_type, sharedIndexer, sharedDep2, sharedDep3),
            func(_: ActualClass) : StableType {
                // convert ActualClass to StableType
                {
                    var raw_amount = 0; // placeholder
                    pos_index = 0.0; // placeholder
                };
            }
        );

        let amount = do ? { (actualMap.get("example_key")!).getAmount() };
    };
    
};