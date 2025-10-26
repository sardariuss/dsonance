import Debug "mo:base/Debug";
import Float "mo:base/Float";
import Result "mo:base/Result";
import Int "mo:base/Int";
import Principal "mo:base/Principal";

import PriceTracker "../../src/protocol/ledger/PriceTracker";
import Duration "../../src/protocol/duration/Duration";
import Types "../../src/protocol/ledger/Types";
import Testify "../utils/Testify";

let { verify } = Testify;
let { equal } = Testify.Testify.float;

// @review: This file has been entirely coded by Claude.

// Mock DEX that returns predictable prices
let mockDex : Types.IDex = {
    swap_amounts = func(_pay_token: Text, _amount: Nat, _receive_token: Text) : async* Result.Result<Types.SwapAmountsReply, Text> {
        #ok({
            pay_chain = "IC";
            pay_symbol = "ckBTC";
            pay_address = "";
            pay_amount = 1;
            receive_chain = "IC";
            receive_symbol = "ckUSDT";
            receive_address = "";
            receive_amount = 50000;
            price = 50000.0;
            mid_price = 50000.0;
            slippage = 0.0;
            txs = [];
        });
    };
    swap = func(_args: Types.AugmentedSwapArgs) : async* Result.Result<Types.SwapReply, Text> {
        #err("Not implemented for test");
    };
    get_main_account = func() : Types.Account {
        { owner = Principal.fromText("aaaaa-aa"); subaccount = null; };
    };
};

// Mock ledgers  
let mockPayLedger : Types.ILedgerFungible = {
    balance_of = func(_account: Types.Account) : async* Nat { 0 };
    transfer = func(_args: Types.Icrc1TransferArgs) : async* Result.Result<Nat, Text> { #err("Service temporarily unavailable") };
    transfer_from = func(_args: Types.TransferFromArgs) : async* Result.Result<Nat, Text> { #err("Service temporarily unavailable") };
    approve = func(_args: Types.ApproveArgs) : async* Result.Result<Nat, Text> { #err("Service temporarily unavailable") };
    get_token_info = func() : Types.LedgerInfo { { token_symbol = "ckBTC"; decimals = 8; fee = 1000; }; };
};

let mockReceiveLedger : Types.ILedgerFungible = {
    balance_of = func(_account: Types.Account) : async* Nat { 0 };
    transfer = func(_args: Types.Icrc1TransferArgs) : async* Result.Result<Nat, Text> { #err("Service temporarily unavailable") };
    transfer_from = func(_args: Types.TransferFromArgs) : async* Result.Result<Nat, Text> { #err("Service temporarily unavailable") };
    approve = func(_args: Types.ApproveArgs) : async* Result.Result<Nat, Text> { #err("Service temporarily unavailable") };
    get_token_info = func() : Types.LedgerInfo { { token_symbol = "ckUSDT"; decimals = 6; fee = 1000; }; };
};

// Test configuration with 1 hour window duration in nanoseconds
let testConfig = {
    window_duration_ns = Duration.toTime(#HOURS(1)); // 3,600,000,000,000 ns
    max_observations = 10;
};

// Mock time function that we can control
var mockTime : Int = 1000000000; // Start at 1 billion nanoseconds

let getMockTime = func() : Int {
    mockTime;
};

// Helper to advance mock time
let advanceTime = func(duration_ns: Nat) {
    mockTime += duration_ns;
};

let test_duration_conversion = func() : async () {
    Debug.print("Testing Duration to nanoseconds conversion");
    
    // Test various duration conversions
    let one_hour_ns = Duration.toTime(#HOURS(1));
    verify(one_hour_ns, 3_600_000_000_000, Testify.Testify.nat.equal);
    
    let one_day_ns = Duration.toTime(#DAYS(1));
    verify(one_day_ns, 86_400_000_000_000, Testify.Testify.nat.equal);
    
    let one_minute_ns = Duration.toTime(#MINUTES(1));
    verify(one_minute_ns, 60_000_000_000, Testify.Testify.nat.equal);
    
    Debug.print("✓ Duration conversion tests passed");
};

let test_twap_tracker_initialization = func() : async () {
    Debug.print("Testing TWAP tracker initialization");
    
    // Create tracked price manually
    let tracked_twap_price = {
        var spot_price : ?Float = null;
        var observations : [{timestamp: Int; price: Float}] = [];
        var twap_cache : ?Float = null;
        var last_twap_calculation : Int = 0;
    };
    
    // Create tracker
    let tracker = PriceTracker.TWAPPriceTracker({
        price_source = #Dex(mockDex);
        tracked_twap_price;
        twap_config = testConfig;
        pay_ledger = mockPayLedger;
        receive_ledger = mockReceiveLedger;
        get_current_time = getMockTime;
    });
    
    // Test initial state
    verify(tracker.get_observations_count(), 0, Testify.Testify.nat.equal);
    
    Debug.print("✓ TWAP tracker initialization test passed");
};

let test_price_fetching_and_twap_calculation = func() : async () {
    Debug.print("Testing price fetching and TWAP calculation");
    
    // Reset mock time
    mockTime := 1000000000;
    
    // Create tracked price manually
    let tracked_twap_price = {
        var spot_price : ?Float = null;
        var observations : [{timestamp: Int; price: Float}] = [];
        var twap_cache : ?Float = null;
        var last_twap_calculation : Int = 0;
    };
    
    // Create tracker
    let tracker = PriceTracker.TWAPPriceTracker({
        price_source = #Dex(mockDex);
        tracked_twap_price;
        twap_config = testConfig;
        pay_ledger = mockPayLedger;
        receive_ledger = mockReceiveLedger;
        get_current_time = getMockTime;
    });
    
    // Fetch first price
    let result1 = await* tracker.fetch_price();
    switch(result1) {
        case(#err(e)) { Debug.trap("Failed to fetch price: " # e); };
        case(#ok(_)) {};
    };
    
    // Verify we have one observation
    verify(tracker.get_observations_count(), 1, Testify.Testify.nat.equal);
    
    // Verify spot price (normalized to unit price: 50000 * 10^6 / 10^8 = 500)
    let spot_price = tracker.get_spot_price();
    verify(spot_price, 500.0, equal);

    // For single observation, TWAP should equal spot price
    let twap_price = tracker.get_twap_price();
    verify(twap_price, 500.0, equal);
    
    Debug.print("✓ Price fetching and single observation TWAP test passed");
};

let test_multiple_observations_twap = func() : async () {
    Debug.print("Testing TWAP calculation with multiple observations");
    
    // Reset mock time
    mockTime := 1000000000;
    
    // Create tracked price manually
    let tracked_twap_price = {
        var spot_price : ?Float = null;
        var observations : [{timestamp: Int; price: Float}] = [];
        var twap_cache : ?Float = null;
        var last_twap_calculation : Int = 0;
    };
    
    // Create a mock DEX that returns different prices
    var priceCounter = 0;
    let prices = [50000.0, 51000.0, 49000.0, 52000.0];
    
    let dynamicMockDex : Types.IDex = {
        swap_amounts = func(_pay_token: Text, _amount: Nat, _receive_token: Text) : async* Result.Result<Types.SwapAmountsReply, Text> {
            let price = prices[priceCounter % prices.size()];
            priceCounter += 1;
            #ok({
                pay_chain = "IC";
                pay_symbol = "ckBTC";
                pay_address = "";
                pay_amount = 1;
                receive_chain = "IC";
                receive_symbol = "ckUSDT";
                receive_address = "";
                receive_amount = Int.abs(Float.toInt(price));
                price = price;
                mid_price = price;
                slippage = 0.0;
                txs = [];
            });
        };
        swap = func(_args: Types.AugmentedSwapArgs) : async* Result.Result<Types.SwapReply, Text> {
            #err("Not implemented for test");
        };
        get_main_account = func() : Types.Account {
            { owner = Principal.fromText("aaaaa-aa"); subaccount = null; };
        };
    };
    
    // Create tracker with dynamic prices
    let tracker = PriceTracker.TWAPPriceTracker({
        price_source = #Dex(dynamicMockDex);
        tracked_twap_price;
        twap_config = testConfig;
        pay_ledger = mockPayLedger;
        receive_ledger = mockReceiveLedger;
        get_current_time = getMockTime;
    });
    
    // Fetch multiple prices with time intervals
    let time_interval_ns = 300_000_000_000; // 5 minutes in nanoseconds
    
    // Fetch price at t=0
    let _ = await* tracker.fetch_price();
    
    // Advance time and fetch price at t=5min
    advanceTime(time_interval_ns);
    let _ = await* tracker.fetch_price();
    
    // Advance time and fetch price at t=10min
    advanceTime(time_interval_ns);
    let _ = await* tracker.fetch_price();
    
    // Advance time and fetch price at t=15min
    advanceTime(time_interval_ns);
    let _ = await* tracker.fetch_price();
    
    // Verify we have 4 observations
    verify(tracker.get_observations_count(), 4, Testify.Testify.nat.equal);
    
    // TWAP should be different from the latest spot price due to averaging
    let final_twap = tracker.get_twap_price();
    let final_spot = tracker.get_spot_price();
    
    // TWAP should be within reasonable bounds (considering price variations)
    // Prices: [50000, 51000, 49000, 52000] -> normalized: [500, 510, 490, 520]
    assert(final_twap > 480.0 and final_twap < 530.0);
    
    Debug.print("✓ Multiple observations TWAP test passed");
};

let test_window_duration_filtering = func() : async () {
    Debug.print("Testing window duration filtering");
    
    // Reset mock time
    mockTime := 1000000000;
    
    // Create a short window duration (10 minutes)
    let shortConfig = {
        window_duration_ns = Duration.toTime(#MINUTES(10)); // 600,000,000,000 ns
        max_observations = 100;
    };
    
    // Create tracked price manually
    let tracked_twap_price = {
        var spot_price : ?Float = null;
        var observations : [{timestamp: Int; price: Float}] = [];
        var twap_cache : ?Float = null;
        var last_twap_calculation : Int = 0;
    };
    
    // Create tracker
    let tracker = PriceTracker.TWAPPriceTracker({
        price_source = #Dex(mockDex);
        tracked_twap_price;
        twap_config = shortConfig;
        pay_ledger = mockPayLedger;
        receive_ledger = mockReceiveLedger;
        get_current_time = getMockTime;
    });
    
    // Fetch initial price
    let _ = await* tracker.fetch_price();
    verify(tracker.get_observations_count(), 1, Testify.Testify.nat.equal);
    
    // Advance time by 5 minutes and fetch price
    advanceTime(Duration.toTime(#MINUTES(5)));
    let _ = await* tracker.fetch_price();
    verify(tracker.get_observations_count(), 2, Testify.Testify.nat.equal);
    
    // Advance time by another 10 minutes (total 15 minutes from start)
    // This should cause the first observation to be outside the 10-minute window
    advanceTime(Duration.toTime(#MINUTES(10)));
    let _ = await* tracker.fetch_price();
    
    // Should have only 2 observations (5min and 15min), first one filtered out
    verify(tracker.get_observations_count(), 2, Testify.Testify.nat.equal);
    
    Debug.print("✓ Window duration filtering test passed");
};

let test_max_observations_limit = func() : async () {
    Debug.print("Testing max observations limit");
    
    // Reset mock time
    mockTime := 1000000000;
    
    // Create config with small max observations
    let limitedConfig = {
        window_duration_ns = Duration.toTime(#HOURS(24)); // Long window
        max_observations = 3; // Small limit
    };
    
    // Create tracked price manually
    let tracked_twap_price = {
        var spot_price : ?Float = null;
        var observations : [{timestamp: Int; price: Float}] = [];
        var twap_cache : ?Float = null;
        var last_twap_calculation : Int = 0;
    };
    
    // Create tracker
    let tracker = PriceTracker.TWAPPriceTracker({
        price_source = #Dex(mockDex);
        tracked_twap_price;
        twap_config = limitedConfig;
        pay_ledger = mockPayLedger;
        receive_ledger = mockReceiveLedger;
        get_current_time = getMockTime;
    });
    
    // Fetch 5 prices with time intervals
    let time_interval_ns = 60_000_000_000; // 1 minute
    
    for (i in [0, 1, 2, 3, 4].vals()) {
        let _ = await* tracker.fetch_price();
        advanceTime(time_interval_ns);
    };
    
    // Should have only 3 observations (the limit)
    verify(tracker.get_observations_count(), 3, Testify.Testify.nat.equal);
    
    Debug.print("✓ Max observations limit test passed");
};

// Run all tests
Debug.print("🧪 Starting TWAPPriceTracker tests");

await test_duration_conversion();
await test_twap_tracker_initialization();
await test_price_fetching_and_twap_calculation();
await test_multiple_observations_twap();
await test_window_duration_filtering();
await test_max_observations_limit();

Debug.print("🎉 All TWAPPriceTracker tests passed!");