---
cover: ../.gitbook/assets/logo.png
coverY: 0
---

# Stake-weighted voting

The Proof-of-Foresight uses a **stake-weighted voting system** based on binary votes. Participants cast votes on statements to determine whether they are **true** **or false**. To vote, users select an outcome (_True_ or _False_), specify **the amount of token** they wish to lock, and commit their stake. The more tokens a user locks, the more their vote influences the outcome in the chosen direction.

<figure><img src="../.gitbook/assets/image (3).png" alt=""><figcaption><p>Example of consensus expressed between 0 and 1</p></figcaption></figure>

The consensus value is determined by the ratio of the **weighted sum** of tokens from _True_ ballots to the **weighted sum** of tokens from all ballots (_True_ and _False_). The weight of each ballot is influenced by a **decay function** over time, ensuring that more recent ballots carry greater influence. This dynamic approach allows the consensus to **evolve naturally** and be contested over **extended periods**.

$$
C = \frac{\sum_{i} d_i \cdot A_i^{\text{(true)}}}{\sum_{j} d_j \cdot A_j}
$$

Where:

* $$C$$ = Consensus value
* $$A_i^{\text{(true)}} =$$ Amount of token in _True_ ballots
* $$A_j$$ = Amount of token in all ballots (_True_ and _False_)
* $$d_i, d_j$$ = Decay factor of each ballot, giving more recent ballots higher weight

{% hint style="info" %}
The consensus remains **unaffected** by whether the tokens from ballots are still **locked** or have been **transferred back** to the user. Once a ballot is cast, it continues to influence the vote **indefinitely**, though its impact gradually decreases over time due to the decay factor.
{% endhint %}

The decay factor follows standard exponential decay, with the **ballot's half-life as a protocol-defined parameter**.
