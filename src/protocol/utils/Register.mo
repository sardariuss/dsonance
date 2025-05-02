import Types "../Types";

import Map "mo:map/Map";

import Iter "mo:base/Iter";

module {

    type Register<T> = Types.Register<T>;

    // Function to create a new Register
    public func new<T>(): Register<T> {
        {
            var index = 0;
            map = Map.new<Nat, T>();
        };
    };

    // Function to add a new element to the Register
    public func add<T>(register: Register<T>, value: T): Nat {
        let id = register.index;
        Map.set(register.map, Map.nhash, id, value);
        register.index += 1;
        id;
    };

    // Function to find an element by its ID
    public func find<T>(register: Register<T>, id: Nat): ?T {
        Map.get(register.map, Map.nhash, id);
    };

    // Function to remove an element by its ID
    public func remove<T>(register: Register<T>, id: Nat): ?T {
        Map.remove(register.map, Map.nhash, id);
    };

    // Function to delete an element by its ID
    public func delete<T>(register: Register<T>, id: Nat) {
        Map.delete(register.map, Map.nhash, id);
    };

    // Function to iterate over all elements in the Register
    public func vals<T>(register: Register<T>): Iter.Iter<T> {
        Map.vals(register.map);
    };

    // Function to iterate over all entries in the Register
    public func entries<T>(register: Register<T>): Iter.Iter<(Nat, T)> {
        Map.entries(register.map);
    };

    // Function to check if an element exists in the Register
    public func has<T>(register: Register<T>, id: Nat): Bool {
        Map.has(register.map, Map.nhash, id);
    };

};