import Map "mo:map/Map";

module {

    type Iter<T> = Map.Iter<T>;

    public func map<X, Y>(original_iter: Iter<X>, f: X -> Y) : Iter<Y> {

        let mapped_iter : Iter<Y> = {

            prev = func(): ?Y {
                switch (original_iter.prev()) {
                    case (?x) { ?f(x); };
                    case (null) { null; };
                };
            };

            next = func(): ?Y {
                switch (original_iter.next()) {
                    case (?x) { ?f(x); };
                    case (null) { null; };
                };
            };

            peekPrev = func(): ?Y {
                switch (original_iter.peekPrev()) {
                    case (?x) { ?f(x); };
                    case (null) { null; };
                };
            };

            peekNext = func(): ?Y {
                switch (original_iter.peekNext()) {
                    case (?x) { ?f(x); };
                    case (null) { null; };
                };
            };

            current = func(): ?Y {
                switch (original_iter.current()) {
                    case (?x) { ?f(x); };
                    case (null) { null; };
                };
            };

            started = func(): Bool {
                original_iter.started();
            };

            finished = func(): Bool {
                original_iter.finished();
            };

            movePrev = func(): Iter<Y> {
                ignore original_iter.movePrev();
                mapped_iter;
            };

            moveNext = func(): Iter<Y> {
                ignore original_iter.moveNext();
                mapped_iter;
            };

            reset = func(): Iter<Y> {
                ignore original_iter.reset();
                mapped_iter;
            };
        };

        return mapped_iter;
    };
}