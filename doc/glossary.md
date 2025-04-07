---
cover: .gitbook/assets/logo.png
coverY: 0
---

# Glossary

#### Effective Voting Power (EVP)

For a vote, the EVP represents the total amount of token used to determine the consensus. It is calculated as the sum of tokens locked in all ballots (both True and False), weighted by their decay over time, as explained in [stake-weighted-voting.md](protocol-beta-version/stake-weighted-voting.md "mention").

* When a new ballot is added, EVP increases by the amount locked in that ballot.
* When time passes without new ballots being added, EVP decreases due to decay.
* EVP and TVL (Total Value Locked) are not the same, as TVL only accounts for currently locked funds, while EVP considers the decayed influence of past votes.

**Example:**

<table><thead><tr><th>Time</th><th width="282">Event</th><th width="155">EVP</th><th>TVL</th></tr></thead><tbody><tr><td><span class="math">t_0</span></td><td>Alice adds a ballot of $100</td><td>$100</td><td>$100</td></tr><tr><td><span class="math">t_1</span></td><td>(Alice ballot stays locked)</td><td>$95</td><td>$100</td></tr><tr><td><span class="math">t_2</span></td><td>Alice ballot gets unlocked</td><td>$90</td><td>$0</td></tr><tr><td><span class="math">t_3</span></td><td>Bob adds a ballot of $200</td><td>$285</td><td>$200</td></tr></tbody></table>

#### Total Value Locked (TVL)

For a vote, the TVL represents the total amount of tokens that are currently locked in active ballots. Unlike the EVP, which accounts for both time and decay, the TVL is a snapshot of the present state of locked funds. It increases when a new ballot is added and decreases when a ballot's lock period ends.
