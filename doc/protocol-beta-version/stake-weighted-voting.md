---
cover: ../.gitbook/assets/towerviewers.webp
coverY: 0
---

# Stake-weighted positions

The Proof-of-Foresight uses a **stake-weighted position system** based on binary positions. Participants open positions on statements to determine whether they are **true** **or false**. To open a position, users select an outcome (_True_ or _False_), specify **the amount of token** they wish to lock, and commit their stake. The more tokens a user locks, the more their position influences the outcome in the chosen direction.

<figure><img src="../.gitbook/assets/image (3).png" alt=""><figcaption><p>Example of consensus expressed between 0 and 1</p></figcaption></figure>

The consensus value is determined by the ratio of the **weighted sum** of tokens from _True_ positions to the **weighted sum** of tokens from all positions (_True_ and _False_). The weight of each position is influenced by a **decay function** over time, ensuring that more recent positions carry greater influence. This dynamic approach allows the consensus to **evolve naturally** and be contested over **extended periods**.

$$
C = \frac{\sum_{i} d_i \cdot A_i^{\text{(true)}}}{\sum_{j} d_j \cdot A_j}
$$

Where:

* $$C$$ = Consensus value
* $$A_i^{\text{(true)}} =$$ Amount of token in _True_ positions
* $$A_j$$ = Amount of token in all positions (_True_ and _False_)
* $$d_i, d_j$$ = Decay factor of each position, giving more recent positions higher weight

{% hint style="info" %}
The consensus remains **unaffected** by whether the tokens from positions are still **locked** or have been **transferred back** to the user. Once a position is opened, it continues to influence the pool **indefinitely**, though its impact gradually decreases over time due to the decay factor.
{% endhint %}

The decay factor follows standard exponential decay, with the **position's half-life as a protocol-defined parameter**.
