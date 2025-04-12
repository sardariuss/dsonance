import Iter "mo:base/Iter";

module {

    type Iter<T> = Iter.Iter<T>;

    public func map<X, Y>(iter: Iter<X>, f: X -> Y) : Iter<Y> {
        func next() : ?Y {
            label get_next while(true) {
                switch(iter.next()){
                    case(null) { break get_next; };
                    case(?e){
                        return ?f(e);
                    };
                };
            };
            null;
        };
        return { next };
    };
}