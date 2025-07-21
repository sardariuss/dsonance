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
