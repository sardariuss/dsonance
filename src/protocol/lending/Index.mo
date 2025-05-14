
module {

    public type Index = {
        timestamp: Nat;
        value: Float;
    };

    public func less_or_equal(a: Index, b: Index) : Bool {
        a.timestamp <= b.timestamp and a.value <= b.value;
    };

    public func equal(a: Index, b: Index) : Bool {
        a.timestamp == b.timestamp and a.value == b.value;
    };
    
};