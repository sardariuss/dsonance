---
cover: ../.gitbook/assets/towerviewers.webp
coverY: 0
---

# Dynamic lock duration

The **lock duration** is determined by the **pool's popularity** at the time the **position** is opened, making each **lock duration independent**, even for positions opened in the same pool.

<figure><img src="../.gitbook/assets/lock_duration.png" alt=""><figcaption><p>The lock duration depends on the popularity of the pool at the time the position is opened and increases with subsequent positions</p></figcaption></figure>

The **hotness** of a position represents its **recent popularity** and determines how long positions remain locked. It is calculated using the sum of a position's own token amount plus the weighted influence of surrounding positions, adjusted by a **decay factor**:

$$
\text{hotness}_i = \text{amount}_i + \sum_{j < i} \left(\frac{\text{decay}_j}{\text{decay}_i} \times \text{amount}_j\right) + \sum_{j > i} \left(\frac{\text{decay}_i}{\text{decay}_j} \times \text{amount}_j\right)
$$

This formula ensures that **earlier positions contribute to later ones**, while newer positions also have a **retroactive impact** on older ones when popularity grows. As a result, lock durations extend naturally when pools gain traction over time.

To convert hotness into a lock duration, a **power scaling** function is applied. This function translates hotness into a **meaningful lock duration** while preventing extreme values (e.g., durations of just 10 seconds or over 100 years).&#x20;

<div align="center" data-full-width="false"><figure><img src="../.gitbook/assets/power_scaler.png" alt="" width="563"><figcaption><p>Graph of the lock duration as a function of hotness. Here the nominal lock duration for 100 sats is set to 3 days. As hotness increases, the lock duration follows a power function, reaching 768 days (approximately 2 years) for a hotness of 1 BTC.</p></figcaption></figure></div>

The function follows a power law, ensuring that the **duration doubles for each order of magnitude increase in hotness**:

$$
\text{duration} = \text{nominal\_lock\_duration} \times \text{hotness}^{\log(2)}
$$

where:

* $$nominal\_lock\_duration$$ is a protocol parameter representing the lock duration for the smallest possible position amount.
* $$log(2)$$ ensures that the duration doubles for each 10× increase in hotness.
