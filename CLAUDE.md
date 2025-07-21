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