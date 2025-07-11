# Dsonance

_My views are changing as much as the world itself is changing. Your views should change when the evidence changes and assumptions that you had in the past are proven wrong \[...] If you pay enough attention you can rate your own performance, just as if you're betting on sports \[...] To tell the truth is my main view and I plan to do that to the best of my ability._

> [Tucker Carlson, 2024 World Government Summit in Dubai.](https://youtu.be/mMXikZM\_O80?si=bSkrQ0C2GeTJe7TV\&t=118)

Dsonance is designed to help communities converge on empirical consensus — shared agreement on claims that can be evaluated based on evidence, observation, and reasoning. This includes scientific findings, historical facts, and other truth-based knowledge.

## Installation

You need to install Node.js and the internet computer SDK: https://internetcomputer.org/docs/building-apps/getting-started/install

You also need mops: https://cli.mops.one/

Then you can install the project dependencies with:

```bash
npm install
mops install
```

Then you're ready to build the project locally:

```bash
dfx start --background --clean
./install-local.sh
cd test/ts
node scenario.cjs
cd -
npm run start
```

⚠️ In install-local.sh the internet identity canister is installed with dfx deps which requires an internet connection. If the script ever fails during this stage, try to run these 3 lines before running the script:
```bash
dfx deps pull
dfx deps init
dfx deps deploy internet_identity
```

The frontend should be available on localhost:3000

## Credits

* Acelon font: https://www.fontspace.com/acelon-blur-font-f115699

## Improvements
 - The retrieval of the supply and collateral ledgers should not be hardcoded in the frontend be retrieved from the protocol canister
 - The preview of the foresight and mining shall be fixed
 - The foresight shall not be in the BallotType
 - DebtInfo is used for transfering ckBTC and DSN tokens. It shall only be used for DSN tokens, a new easier type shall be used instead for ckBTC.
 - The DebtProcessor shall be reworked so the transfer are done asynchronously by the user or at the finalization of the disbursement.
