import Float "mo:base/Float";
import Map "mo:map/Map";

module {

    type Iter<T> = Map.Iter<T>;

    public func logistic_regression({
        x: Float;
        mu: Float;
        sigma: Float;
    }) : Float {
        1 / (1 + Float.exp(-((x - mu) / sigma)));
    };

    public func integrate_decay_with_offset({
        a: Float;
        b: Float;
        lambda: Float;
        offset: Float;
    }) : Float {
        (1 - offset) / -lambda * (Float.exp(-lambda * b) - Float.exp(-lambda * a)) + offset * (b - a);
    };

    public func percentage_to_ratio(percentage: Float) : Float {
        percentage / 100.0;
    };

    public func ratio_to_percentage(ratio: Float) : Float {
        ratio * 100.0;
    };

    public func is_normalized(x: Float) : Bool {
        x >= 0.0 and x <= 1.0;
    };

    public func ceil_to_int(x: Float) : Int {
        if (x == Float.floor(x)) { Float.toInt(x) }
        else { Float.toInt(x) + 1 };
    };
    
};