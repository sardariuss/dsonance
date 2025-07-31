# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Important**: If, while doing a task, you come across something new, non-obvious, or that you had to figure out (something you "learned"), write it down here. This file is used to store cumulative knowledge and emerging conventions across the project.

## Development Commands

**Start Development Server**
```bash
dfx start --background --clean
./install-local.sh
npm run start
```

**Build Project**
```bash
npm run build
```

**Run Tests**
```bash
npm run test
```

**Run Motoko Tests**
```bash
mops test <filename>  # e.g., mops test lendingpool (for lendingpool.test.mo)
```

**Format Code**
```bash
npm run format
```

**Test Scenario**
```bash
cd test/ts
node scenario.cjs
cd -
```

## Project Architecture

### Technology Stack
- **Frontend**: React 19 with TypeScript, Vite, Tailwind CSS
- **Backend**: Motoko (Internet Computer)
- **Blockchain**: Internet Computer Protocol (ICP)
- **Package Manager**: npm + mops (Motoko packages)

### Canister Structure
The project uses multiple canisters (smart contracts):
- `protocol` - Main protocol logic (src/protocol/main.mo)
- `backend` - Backend API (src/backend/main.mo)
- `frontend` - Web assets
- `ck_btc` - ckBTC ledger (src/ledger/main.mo)
- `ck_usdt` - ckUSDT ledger (src/ledger/main.mo)
- `dex` - DEX functionality (src/dex/main.mo)
- `minter` - Token minting
- `icp_coins` - Price oracle
- `internet_identity` - Authentication

### Key Frontend Components
- **React Context**: `ThemeContext` for dark/light theme, `FungibleLedgerContext`, `ProtocolContext`
- **Actors**: Located in `src/frontend/actors/` for canister communication
- **Routing**: React Router in `src/frontend/router/`
- **State Management**: React hooks in `src/frontend/components/hooks/`

### Protocol Architecture
- **Main Protocol**: `src/protocol/main.mo` with migration system
- **Lending System**: `src/protocol/lending/` with interest rates, borrowing, supply
- **Voting System**: `src/protocol/votes/` with ballot aggregation and incentives
- **Duration System**: `src/protocol/duration/` with decay calculations
- **Utilities**: `src/protocol/utils/` for common functionality

### Local Development Setup
1. Install dependencies: `npm install && mops install`
2. Start dfx: `dfx start --background --clean`
3. Deploy locally: `./install-local.sh`
4. Run test scenario: `cd test/ts && node scenario.cjs && cd -`
5. Start frontend: `npm run start`
6. Access at: `localhost:3000`

## Important Notes

- The install-local.sh script requires internet connection for Internet Identity deployment
- If deployment fails, manually run: `dfx deps pull && dfx deps init && dfx deps deploy internet_identity`
- The DEX liquidity affects ckUSDT/ckBTC price calculations
- Protocol uses simulated time with 100x dilation factor for testing
- Supply cap: 1M ckUSDT, borrow cap: 800k ckUSDT (configurable in install-local.sh)

## Lock Duration Computation

The protocol uses a dynamic lock duration system that adapts based on the "hotness" of votes. The lock duration for ballots is computed using the **DurationScaler** (`src/protocol/duration/DurationScaler.mo`).

### How it Works

1. **Hotness Calculation**: When a ballot is submitted, the system calculates the "hotness" of the vote based on how much USDT is locked around the ballot's timestamp. Higher amounts of locked USDT indicate a "hotter" vote.

2. **Duration Scaling**: The lock duration is computed using a power scaling function:
   ```
   duration = a * hotness^(log_10(b))
   ```
   Where:
   - `a` is the multiplier parameter (controls baseline duration)
   - `b` is the logarithmic base parameter (controls the power law exponent)
   - `hotness` is the amount of USDT locked around the ballot's timestamp
   - `log_10(b)` determines the scaling exponent (e.g., b=3.25 gives exponent ≈ 0.512)

3. **Scaling Behavior**: As hotness increases, the duration increases but at a decreasing rate (sub-linear scaling when b < 10). This is the desired behavior for preventing extremely long lock durations while still scaling appropriately with activity. The sub-linear relationship means that highly active votes don't result in impractically long lock periods.

4. **Purpose**: This system prevents absurd lock durations (e.g., 10 seconds or 100 years) by scaling the duration based on the economic activity around the vote. More active votes (higher hotness) get different lock durations than less active ones, but the scaling is controlled to remain reasonable.

5. **Configuration**: The `a` and `b` parameters can be configured in the protocol factory to tune the scaling behavior according to the desired economics. For example:
   - `b = 10` gives linear scaling (hotness^1)
   - `b = 100` gives quadratic scaling (hotness^2)
   - `b = 3.25` gives sub-linear scaling (hotness^0.512, like square root)

## Frontend Development Guidelines

### IC-Reactor Actor Hooks Performance

**❌ AVOID: Using useEffect to capture actor call methods**
```typescript
// DON'T DO THIS - causes high CPU usage
const { call: fetchData } = backendActor.useQueryCall({
  functionName: 'get_data',
  args: [id],
});

useEffect(() => {
  fetchData(); // This pattern causes performance issues
}, [id, fetchData]);
```

**✅ DO: Let ic-reactor handle the calls automatically**
```typescript
// DO THIS - let ic-reactor manage the calls
const { data } = backendActor.useQueryCall({
  functionName: 'get_data',
  args: [id], // Args changes trigger automatic refetch
});
```

**Reason**: Capturing `call` methods from ic-reactor hooks in useEffect dependencies can cause excessive re-renders and high CPU usage. The ic-reactor library is designed to handle automatic refetching when arguments change, making manual useEffect calls unnecessary and potentially harmful to performance.

## State Persistence and Stable Memory Guidelines

### Mutable State References in Classes

**❌ AVOID: Creating copies of mutable state structs when passing to classes**
```motoko
// DON'T DO THIS - creates a copy, loses stable memory persistence
let mutable_state = { var value = state.some_field.value; };
let instance = MyClass({ mutable_field = mutable_state; });
```

**✅ DO: Pass the entire mutable struct reference**
```motoko
// DO THIS - maintains reference to stable memory
let instance = MyClass({ mutable_field = state.some_field; });
```

**Critical Pattern**: When working with mutable state that needs to persist across upgrades:

1. **State Structure**: Define mutable fields as `{ var value: T }` in the State type
   ```motoko
   public type State = {
       last_mint_timestamp: { var value: Nat; };
       // ... other fields
   };
   ```

2. **Class Parameters**: Accept the full struct reference
   ```motoko
   public class MyClass({
       mutable_field: { var value: Nat; };
   }) {
       // Modifications to mutable_field.value will persist in stable memory
   }
   ```

3. **Factory Injection**: Pass the struct directly, not a copy
   ```motoko
   let instance = MyClass({ mutable_field = state.mutable_field; });
   ```

**Reason**: Creating `{ var value = some_value }` makes a copy of the value, breaking the reference to stable memory. The original state won't be updated, and changes won't persist across canister upgrades. Always pass the entire mutable struct to maintain the reference to stable memory.

## Code Readability Guidelines

### Avoid Deep Nesting with Early Returns (Guard Clauses)

**❌ AVOID: Deep nesting with nested switch/if statements**
```motoko
public func claim_rewards(account: Account) : async* ?Nat {
    switch (Map.get(rewards, hash, account)) {
        case (null) { null; };
        case (?tracker) {
            if (tracker.owed > 0) {
                let result = await* transfer(tracker.owed, account);
                switch (result) {
                    case (#ok(tx_id)) { ?tracker.owed; };
                    case (#err(_)) { null; };
                };
            } else {
                null;
            };
        };
    };
}
```

**✅ DO: Use early returns (guard clauses) to reduce nesting**
```motoko
public func claim_rewards(account: Account) : async* ?Nat {
    let tracker = switch (Map.get(rewards, hash, account)) {
        case (null) { return null; };
        case (?t) { t; };
    };
    
    if (tracker.owed == 0) {
        return null;
    };
    
    let result = await* transfer(tracker.owed, account);
    let tx_id = switch (result) {
        case (#err(_)) { return null; };
        case (#ok(id)) { id; };
    };
    
    // Main logic here at consistent indentation
    ?tracker.owed;
}
```

**Pattern Benefits**:
- **Readability**: Main logic flows at consistent indentation level
- **Maintainability**: Error conditions are handled upfront and clearly
- **Cognitive Load**: Reduces mental tracking of nested conditions
- **Early Exit**: Handles edge cases immediately, keeping main logic clean

**When to Apply**:
- Functions with optional values that are required for the rest of the logic
- Multiple validation checks that should fail fast
- Error handling that doesn't need complex recovery logic
- Any time nesting exceeds 2-3 levels

This pattern is also known as "guard clauses" or "early return pattern" in software engineering.

## Parameter and Type System Guidelines

### Parameter Architecture

The protocol follows a strict parameter architecture to maintain clean separation between human-readable configuration and efficient backend execution:

1. **InitParameters**: Human-readable parameters used for canister initialization and updates
   - Contain `Duration` types for time-based values
   - Used in canister arguments and configuration files
   - Example: `window_duration: Duration`

2. **Parameters**: Backend-friendly parameters stored in stable State
   - Contain nanosecond-based time values (`_ns` suffix)
   - Optimized for performance and storage
   - Example: `window_duration_ns: Nat`

3. **Conversion Flow**:
   - `InitParameters` → converted during initialization → `Parameters` → stored in `State`
   - Parameters can be updated via canister redeploy with `#update` argument
   - Conversion happens once during initialization/update to avoid runtime overhead

### Type Naming Conventions

- **S-prefix**: Types prefixed with `S` (e.g., `SParameters`) are **Shared** and human-readable
  - Used for public API queries and external interfaces
  - Handled by `SharedConversions` module for type conversion

- **Time/Duration Naming**:
  - Use specific unit suffixes: `_ns` (nanoseconds), `_s` (seconds), `_ms` (milliseconds)
  - Use `Duration` type for human-readable time parameters
  - Example: `window_duration_ns: Nat` vs `window_duration: Duration`

### Parameter Update Strategy

- Parameter updates require canister redeploy with `#update` argument
- This design choice avoids saturating code with parameter update logic across all objects
- Since parameter updates are infrequent operations, this approach maintains clean architecture
- All objects requiring parameters receive them via injection from Factory.mo

## Test Files
- Motoko tests: `tests/protocol/`
- TypeScript tests: `src/frontend/tests/`
- Mock implementations: `tests/mocks/`
- Integration scenarios: `tests/ts/` (`.cjs`)