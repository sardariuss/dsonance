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
        return (1 - offset) / -lambda * (Float.exp(-lambda * b) - Float.exp(-lambda * a)) + offset * (b - a);
    };

    public func percentageToRatio(percentage: Float) : Float {
        return percentage / 100.0;
    };
    
}