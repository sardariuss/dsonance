import ForesightUpdater "../../src/protocol/ForesightUpdater";
import Duration "../../src/protocol/duration/Duration";
import Types "../../src/protocol/Types";
import MapUtils "../../src/protocol/utils/Map";

import { test; suite; } "mo:test";
import Map "mo:map/Map";
import Array "mo:base/Array";

import { verify; Testify; } = "../utils/Testify";

suite("ForesightUpdater", func(){

    // Define a type for test data
    type TestData = {
        yield_state: ForesightUpdater.InputYield;
        // Store expected foresights for multiple items using their keys
        expected_foresights: [(Text, Types.Foresight)];
    };

    var yield : ForesightUpdater.InputYield = {
        earned = 0.0;
        apr = 0.0;
        time_last_update = 0;
    };

    let updater = ForesightUpdater.ForesightUpdater({
        get_yield = func () : ForesightUpdater.InputYield { yield; };
    });

    test("Update with a single item", func(){

        let foresights = Map.new<Text, Types.Foresight>();

        let items = Map.new<Text, ForesightUpdater.ForesightItem>();

        Map.set(items, Map.thash, "item1", {
            timestamp = 0;
            release_date = Duration.toTime(#YEARS(1));
            amount = 100;
            discernment = 1.0;
            consent = 1.0;
            update_foresight = func(foresight: Types.Foresight, _: Nat) {
                Map.set(foresights, Map.thash, "item1", foresight);
            };
        });

        // Buffer with test data - expected_foresights is now an array
        let test_buffer : [TestData] = [
            {
                yield_state = { earned = 0.0; apr = 10.0; time_last_update = Duration.toTime(#YEARS(0)); };
                expected_foresights = [("item1", { apr = {current = 10.0 ; potential = 10.0 }; reward = 10 })];
            },
            {
                yield_state = { earned = 5.0; apr = 10.0; time_last_update = Duration.toTime(#YEARS(1)) / 2; };
                expected_foresights = [("item1", { apr = {current = 10.0 ; potential = 10.0 }; reward = 10 })];
            },
            {
                yield_state = { earned = 10.0; apr = 10.0; time_last_update = Duration.toTime(#YEARS(1)); };
                expected_foresights = [("item1", { apr = {current = 10.0 ; potential = 10.0 }; reward = 10 })];
            }
        ];

        // Loop through the test buffer
        for (data in Array.vals(test_buffer)) {
            yield := data.yield_state; // Update the yield state
            updater.update_foresights(Map.vals(items));
            // Loop through expected foresights for verification
            for ((key, expected) in Array.vals(data.expected_foresights)) {
                 verify<Types.Foresight>(
                    MapUtils.getOrTrap(foresights, Map.thash, key),
                    expected,
                    Testify.foresight.equal
                );
            }
        };

    });

    test("Update with two items", func(){

        let foresights = Map.new<Text, Types.Foresight>();
        let items = Map.new<Text, ForesightUpdater.ForesightItem>();

        // Item 1: 100 amount, 1 year release
        Map.set(items, Map.thash, "item1", {
            timestamp = 0;
            release_date = Duration.toTime(#YEARS(1));
            amount = 100;
            discernment = 1.0;
            consent = 1.0;
            update_foresight = func(foresight: Types.Foresight, _: Nat) {
                Map.set(foresights, Map.thash, "item1", foresight);
            };
        });

        // Item 2: 200 amount, 2 years release
        Map.set(items, Map.thash, "item2", {
            timestamp = 0;
            release_date = Duration.toTime(#YEARS(2));
            amount = 200;
            discernment = 1.0;
            consent = 1.0;
            update_foresight = func(foresight: Types.Foresight, _: Nat) {
                Map.set(foresights, Map.thash, "item2", foresight);
            };
        });

        // Buffer with test data for two items
        let test_buffer : [TestData] = [
            {
                yield_state = { earned = 0.0; apr = 10.0; time_last_update = Duration.toTime(#YEARS(0)); }; // APR 10%
                expected_foresights = [
                    ("item1", { apr = {current = 10.0 ; potential = 10.0 }; reward = 10 }), // 100 * 10% * 1 = 10
                    ("item2", { apr = {current = 10.0 ; potential = 10.0 }; reward = 40 })  // 200 * 10% * 2 = 40
                ];
            },
            {
                yield_state = { earned = 15.0; apr = 5.0; time_last_update = Duration.toTime(#YEARS(1)) / 2; }; // APR changes to 5%, 0.5 years
                expected_foresights = [
                    ("item1", { apr = {current = 5.0 ; potential = 5.0 }; reward = 5 }), // 100 * 5% * 1 = 5
                    ("item2", { apr = {current = 5.0 ; potential = 5.0 }; reward = 20 }) // 200 * 5% * 2 = 20
                ];
            },
            {
                yield_state = { earned = 30.0; apr = 20.0; time_last_update = Duration.toTime(#YEARS(1)); }; // APR changes to 20%, 1 year
                expected_foresights = [
                     ("item1", { apr = {current = 20.0 ; potential = 20.0 }; reward = 20 }), // 100 * 20% * 1 = 20
                     ("item2", { apr = {current = 20.0 ; potential = 20.0 }; reward = 80 })  // 200 * 20% * 2 = 80
                ];
            }
        ];

        // Loop through the test buffer
        for (data in Array.vals(test_buffer)) {
            yield := data.yield_state; // Update the yield state
            updater.update_foresights(Map.vals(items));
            // Loop through expected foresights for verification
            for ((key, expected) in Array.vals(data.expected_foresights)) {
                 verify<Types.Foresight>(
                    MapUtils.getOrTrap(foresights, Map.thash, key),
                    expected,
                    Testify.foresight.equal
                );
            }
        };
    });

})