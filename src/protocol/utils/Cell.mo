module {

    type Var<V> = {
        var value: V;
    };

    public class Cell<V>(variable: Var<V>){

        public func set(value: V) {
            variable.value := value;
        };

        public func get() : V {
            variable.value;
        };

    };

};