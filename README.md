# Dsonance

_My views are changing as much as the world itself is changing. Your views should change when the evidence changes and assumptions that you had in the past are proven wrong \[...] If you pay enough attention you can rate your own performance, just as if you're betting on sports \[...] To tell the truth is my main view and I plan to do that to the best of my ability._

> [Tucker Carlson, 2024 World Government Summit in Dubai.](https://youtu.be/mMXikZM\_O80?si=bSkrQ0C2GeTJe7TV\&t=118)

## Canister arguments

* `deposit_ledger`: the principal of the ICRC-1/ICRC-2 ledger used for the ballots (aims to be ckBTC)
* `reward_ledger`: the principal of the ICRC-1/ICRC-2 ledger used for the rewards
* `parameters.nominal_lock_duration`: the duration of the lock for 1 satoshi
* `parameters.ballot_half_life`: used to compute the effect of other ballots on a given ballot to update the lock date, so that the shorter (resp. the longer) the timespan between the date of that ballot and the others, the more (resp. the less) time is added to the ballot's lock. The same parameter is used to make the ballot decay

## Credits

* Acelon font: https://www.fontspace.com/acelon-blur-font-f115699

## TODO
 - The retrieval of the supply and collateral ledgers should not be hardcoded in the frontend be retrieved from the protocol canister
 - The management of decimals should be harmonized in the frontend (see token.tsx and usage)
 - The preview of the foresight and mining shall be fixed
 - The foresight shall not be in the BallotType
 - DebtInfo is used for transfering ckBTC and DSN tokens. It shall only be used for DSN tokens, a new easier type shall be used instead for ckBTC.
 - The DebtProcessor shall be reworked so the transfer are done asynchronously by the user or at the finalization of the disbursement.
 