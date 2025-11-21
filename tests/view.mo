import Map "mo:map/Map";
import Float "mo:base/Float";
import Principal "mo:base/Principal";

// see https://x.com/i/grok/share/35BXDaiTvQO9hGgENarcvtNEy
module {

    type View<K, V> = {
        get: K -> ?V;
    };

    public func view<K, V1, V2>(
        stable_map: Map.Map<K, V1>,
        utils: Map.HashUtils<K>,
        convert: V1 -> V2,
    ) : View<K, V2> = object {
    
        public func get(key: K) : ?V2 {
            do ?{ convert(Map.get(stable_map, utils, key)!); };
        };
    };

    // Stable type
    type StableOrderLimit = {
        principal: Principal;
        var raw_amount: Nat;
        limit_dissent: Float;
        supply_index: Float;
    };

    // Type used in lending
    type SupplyPosition = {
        principal: Principal;
        var raw_amount: Nat;
        supply_index: Float;
    };

    type LimitOrder = {
        principal: Principal;
        limit_dissent: Float;
        getAmount: () -> Float;
    };

    func toLimitOrder(stableOrderLimit: StableOrderLimit, sharedIndexer: { get_current_index: () -> Float; }) : LimitOrder = object {
        
        public func getAmount() : Float {
            Float.fromInt(stableOrderLimit.raw_amount) * sharedIndexer.get_current_index() / stableOrderLimit.supply_index;
        };
        
        public let principal = stableOrderLimit.principal;
        public let limit_dissent = stableOrderLimit.limit_dissent;
    };

    class SupplyPositionController(
        positions: View<Text, SupplyPosition>
    ){
        // work on positions...
        let position_supply_index = do ? { (positions.get("test"))!.supply_index; };
        
    };

    class LimitOrderController(
        orders: View<Text, LimitOrder>
    ){
        // work on orders...
        let order_amount = do ? { (orders.get("test"))!.getAmount() };
    };

    public func example_limit_order() : () {
        let stable_map = Map.new<Text, StableOrderLimit>();
        let sharedIndexer = {
            get_current_index = func() : Float { Float.fromInt(100); };
        };

        let mapSupplyPositions = view(
            stable_map,
            Map.thash,
            func(stable_type) : SupplyPosition = stable_type
        );

        let mapLimitOrders = view(
            stable_map,
            Map.thash,
            func(stable_type) = toLimitOrder(stable_type, sharedIndexer)
        );

        // New elments should be added to the stable map, because the smart map has only partial types
        Map.set(stable_map, Map.thash, "test", {
            principal = Principal.fromText("aaaaa-aa");
            var raw_amount = 1000;
            limit_dissent = 0.05;
            supply_index = 1.01;
        });

        let supplyController = SupplyPositionController(mapSupplyPositions);
        let limitOrderController = LimitOrderController(mapLimitOrders);
    };
    
};