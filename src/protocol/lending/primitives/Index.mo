import LendingTypes "../Types";

module {

    type Index = LendingTypes.Index;

    public func less_or_equal(a: Index, b: Index) : Bool {
        a.timestamp <= b.timestamp and a.value <= b.value;
    };

    public func equal(a: Index, b: Index) : Bool {
        a.timestamp == b.timestamp and a.value == b.value;
    };

    public func is_valid(index: Index) : Bool {
        index.value >= 0.0;
    };
    
};