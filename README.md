---
icon: hand-wave
---

# Resonance.defi

_My views are changing as much as the world itself is changing. Your views should change when the evidence changes and assumptions that you had in the past are proven wrong \[...] If you pay enough attention you can rate your own performance, just as if you're betting on sports \[...] To tell the truth is my main view and I plan to do that to the best of my ability._

> [Tucker Carlson, 2024 World Government Summit in Dubai.](https://youtu.be/mMXikZM\_O80?si=bSkrQ0C2GeTJe7TV\&t=118)

## Canister arguments

* `deposit_ledger`: the principal of the ICRC-1/ICRC-2 ledger used for the ballots (aims to be ckBTC)
* `reward_ledger`: the principal of the ICRC-1/ICRC-2 ledger used for the rewards
* `parameters.nominal_lock_duration`: the duration of the lock for 1 satoshi
* `parameters.ballot_half_life`: used to compute the effect of other ballots on a given ballot to update the lock date, so that the shorter (resp. the longer) the timespan between the date of that ballot and the others, the more (resp. the less) time is added to the ballot's lock. The same parameter is used to make the ballot decay

## Credits

* Acelon font: https://www.fontspace.com/acelon-blur-font-f115699

## 🚧 TODOs

### Backend

* Verify how decay is used, especially in computing the dissent and consent
* Do not allow an anonymous principal to open a vote
* Verify that the total_amount takes into account the fees

### Frontend

#### Postponed

* Fix approve tokens, right now it only works once -> Will be fixed when bringing real wallet
