---
cover: .gitbook/assets/logo.png
coverY: 0
---

# Glossary

#### Consensus Decayed Value (CDV)

For a pool, the CDV represents the total time-decayed value of all positions contributing to consensus — whether currently locked or already unlocked.
It is calculated as the sum of tokens from all positions (both True and False), weighted by their decay over time, as described in [stake-weighted-voting.md](protocol-beta-version/stake-weighted-voting.md "mention").
* When a new position is locked, CDV increases by the contributed amount.
* As time passes without new participation, CDV gradually decreases due to time decay, reflecting the fading influence of older positions.
* CDV and TVL (Total Value Locked) differ: while TVL measures currently locked capital, CDV measures the effective consensus weight of that capital over time.

**Example:**

<table><thead><tr><th>Time</th><th width="300">Event</th><th width="70">CDV</th><th>TVL</th></tr></thead><tbody><tr><td><span class="math">January</span></td><td>Alice opens a position of $100</td><td>$100</td><td>$100</td></tr><tr><td><span class="math">February</span></td><td>(Alice position remains locked)</td><td>$95</td><td>$100</td></tr><tr><td><span class="math">March</span></td><td>Alice position unlocks</td><td>$90</td><td>$0</td></tr><tr><td><span class="math">April</span></td><td>Bob opens a position of $200</td><td>$285</td><td>$200</td></tr></tbody></table>

#### Total Value Locked (TVL)

For a pool, the TVL represents the total amount of tokens currently held in locked positions.
Unlike CDV, which accounts for both time decay and previously unlocked positions, TVL is a snapshot of live liquidity.

TVL increases when new positions are opened and decreases when their lock period ends.
