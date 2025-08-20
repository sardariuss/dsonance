# Dsonance

## Warning

⚠️ This project is open-sourced solely to comply with the Dorahack's World Computer Hacker League (WCHL) rules. It is not intended for reuse, modification, or deployment outside of this context. Please contact the author before using it elsewhere.

## Mission

_My views are changing as much as the world itself is changing. Your views should change when the evidence changes and assumptions that you had in the past are proven wrong \[...] If you pay enough attention you can rate your own performance, just as if you're betting on sports \[...] To tell the truth is my main view and I plan to do that to the best of my ability._

> [Tucker Carlson, 2024 World Government Summit in Dubai.](https://youtu.be/mMXikZM\_O80?si=bSkrQ0C2GeTJe7TV\&t=118)

Dsonance is designed to help communities converge on empirical consensus — shared agreement on claims that can be evaluated based on evidence, observation, and reasoning. This includes scientific findings, historical facts, and other truth-based knowledge.

## License
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)

As of July 2025, this project is now licensed under the [GNU AGPL v3.0](LICENSE).  

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

## TODO

* Investigate cases which allow re-entry, especially when two async calls are called in the same function (e.g. approve + swap in LedgerAccount). Can 'await?' help with that?
* The foresight updates shall be done on any APR change. The trigger chain is:
 - borrow/repay/supply/withdraw -> indexer.add_raw_supply or remove_raw_supply
  -> the supply is done in Controller.put_ballot
  -> the withdraw is done in Factory after unlock

When adding a supply position, no need to update the indexes up to that time BEFORE adding, but after (in order for queried elments'APR to be correct).
When removing a supply position, need to update the indexes up to that time BEFORE removing (in order for the APR of removed element to be correct), and after (in order for queried elements'APR to be correct).

Problem: if you add a position at t2 when run() should remove a position at t1 < t2, will both APR be wrong? I guess it is something that can be accepted, because the position to be removed is technically still there.
A real problem can arise because the supply_registry calls take_supply_interests using a share as argument, not an amount. So the indexer has to be updated in-between remove_positions, otherwise the share will not be updated to tkae account of the last removal and be wrong. Use the absolute reward instead!!