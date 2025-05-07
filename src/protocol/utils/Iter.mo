import Map "mo:map/Map";
import Debug "mo:base/Debug";

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

    public func filter<X>(original_iter: Iter<X>, acceptEntry: X -> Bool) : Iter<X> {

        let initialize = func(iter: Iter<X>) {
            if (iter.started()){
                Debug.trap("Iter is already started!");
            };

            // Initialize the iterator on the first accepted element
            while (true) {
                switch (iter.current()) {
                    case (?x) { if (acceptEntry(x)) { return; }; };
                    case (null) { return; };
                };
                ignore iter.moveNext();
            };
        };

        initialize(original_iter);

        let filtered_iter : Iter<X> = {

            prev = func(): ?X {
                while (true) {
                    switch (original_iter.prev()) {
                        case (?x) { if (acceptEntry(x)){ return ?x; }; };
                        case (null) { return null; };
                    };
                };
                null; // Somehow required by the compilator
            };

            next = func(): ?X {
                while (true) {
                    switch (original_iter.next()) {
                        case (?x) { if (acceptEntry(x)) { return ?x; } };
                        case (null) { return null; };
                    };
                };
                null; // Somehow required by the compilator
            };

            peekPrev = func(): ?X {
                while (true) {
                    switch (original_iter.peekPrev()) {
                        case (?x) { if (acceptEntry(x)) { return ?x; } };
                        case (null) { return null; };
                    };
                };
                null; // Somehow required by the compilator
            };

            peekNext = func(): ?X {
                switch (original_iter.peekNext()) {
                    case (?x) { if (acceptEntry(x)) { return ?x; } };
                    case (null) { return null; };
                };
                null; // Somehow required by the compilator
            };

            current = func(): ?X {
                original_iter.current();
            };

            started = func(): Bool {
                switch(filtered_iter.peekPrev()){
                    case(null) { false; };
                    case(_) { true; };
                };
            };

            finished = func(): Bool {
                switch(filtered_iter.peekNext()){
                    case(null) { true; };
                    case(_) { false; };
                };
            };

            movePrev = func(): Iter<X> {
                label move_loop while(true) {
                    ignore original_iter.movePrev();
                    switch(original_iter.current()){
                        case (?x) { if (acceptEntry(x)) { break move_loop; }; };
                        case(null) { break move_loop; };
                    };
                };
                filtered_iter;
            };

            moveNext = func(): Iter<X> {
                label move_loop while(true) {
                    ignore original_iter.moveNext();
                    switch(original_iter.current()){
                        case (?x) { if (acceptEntry(x)) { break move_loop; }; };
                        case(null) { break move_loop; };
                    };
                };
                filtered_iter;
            };

            reset = func(): Iter<X> {
                ignore original_iter.reset();

                // Initialize the iterator on the first accepted element
                initialize(original_iter);

                filtered_iter;
            };

        };

        return filtered_iter;
    };


    public func fold_left<X, A>(iter: Iter<X>, base: A, combine: (A, X) -> A) : A {
        var acc = base;
        for (v in iter) {
            acc := combine(acc, v);
        };
        acc;
    };
}