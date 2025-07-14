# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

## Test Files
- Motoko tests: `tests/protocol/`
- TypeScript tests: `src/frontend/tests/`
- Mock implementations: `tests/mocks/`