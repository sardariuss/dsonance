---
cover: ../.gitbook/assets/logo.png
coverY: 0
---

# Voting rewards

Rewards are divided into two parts:

1. **DSN Rewards** – Rewarding participation in the protocol.
2. **Token yield** – Rewarding ballot foresight with DAO's tokens.

***

#### **DSN Rewards**

Contribution rewards are distributed continuously throughout the active period of a lock. The amount each voter receives is proportional to the amount of token in their lock relative to the total amount of token locked in the protocol.

* **Ballot choice does not impact contribution rewards**—only the total locked amount matters.
* Since the total of locked tokens changes over time, contribution is computed using a **time-weighted integral**, ensuring fairness.

$$
\text{contribution} = \int_{t_{\text{lock}}}^{t_{\text{unlock}}} \left( \frac{\text{ballot\_amount}}{\text{total\_locked}(t)} \right) \times \text{minting\_rate} \, dt
$$

***

#### **Dissent and Consent**

{% hint style="info" %}
Totals expressed in the following paragraphs represent the sum of ballots amounts weighted by their decay as expressed in the [stake-weighted-voting.md](stake-weighted-voting.md "mention") chapter.
{% endhint %}

Before defining _token yield_, it is important to introduce two key metrics:

**Dissent**

Dissent measures how much a single token challenges the current consensus. It is defined as:

$$
\text{dissent} =
\begin{cases} 
1 - \text{consensus} = \frac{\text{total\_false}}{\text{total\_false} + \text{total\_true}}, & \text{if choice is true} \\ 
\text{consensus} = \frac{\text{total\_true}}{\text{total\_false} + \text{total\_true}}, & \text{if choice is false} 
\end{cases}
$$

This simplifies to:

$$
\text{dissent} = \frac{\text{total\_opposit}}{\text{total}}
$$

where $$\text{total\_opposit}$$ represents the amount of token locked in ballots that voted the opposite way.

To avoid completely disincentivizing voting when the consensus is already aligned with the voter’s choice, the **dissent** **is adjusted** using a power function controlled by the protocol parameter _**dissent\_steepness**_:

$$
\text{adjusted\_dissent} = \text{dissent}^p
$$

Where $$p$$ (dissent steepness) is a protocol parameter between 0 and 1:

* The closer $$p$$ is to 1, the steeper the curve (meaning the majority is rewarded less).
* The closer $$p$$ is to 0, the more the majority is rewarded.

<div align="center" data-full-width="true"><figure><img src="../.gitbook/assets/image (4).png" alt="" width="532"><figcaption><p>In X, the ratio total_opposit/ total, in Y the dissent. The red curve is the original dissent, the purple curve is the adjusted dissent.</p></figcaption></figure></div>

Since the **ballot itself influences the consensus**, we must account for its weight. The **ballot dissent** is calculated as:

$$
\text{ballot\_dissent} = \int_0^{\text{amount}} \text{adjusted\_dissent}(x) \, dx = \int_0^{\text{amount}} \left( \frac{\text{total\_opposit}}{\text{total} + x} \right)^p dx
$$

{% hint style="info" %}
The beta version slightly modifies the dissent formulation to ensure that a ballot can have dissent even when no previous ballots have been placed in a vote. This adjustment prevents early voters from being unfairly assigned a dissent of zero. This limitation will be removed once limit orders are implemented.
{% endhint %}

$$
\text{ballot\_dissent} = \int_0^{\text{amount}} \left( \min \left( \frac{\text{total\_opposit} + K}{\text{total} + x}, 1 \right) \right)^p dx
$$

where $$K$$ is the _**initial\_dissent\_addend**_ protocol parameter.

***

#### Consent

The **consent** measures how well a single token **aligns** with the current consensus.

$$
\text{consent} =
\begin{cases} 
\text{consensus} = \frac{\text{total\_true}}{\text{total\_false} + \text{total\_true}}, & \text{if choice is right} \\ 
1 - \text{consensus} = \frac{\text{total\_false}}{\text{total\_false} + \text{total\_true}}, & \text{if choice is false}
\end{cases}
$$

This can be simplified as:

$$
\text{consent} = \frac{\text{total\_same}}{\text{total}}
$$

To incentivize participants whose choice aligns with the consensus, the consent is adjusted using a logistic function controlled by the protocol parameter _**consent\_steepness.**_

$$
\text{ballot\_consent} = \text{adjusted\_consent} = \frac{1}{1 + e^{-\frac{\text{consent} - \mu}{\sigma}}}
$$

Where:

* $$\mu = \text{total} * 0.5$$
* $$\sigma = \text{total} * \text{consent\_steepness}$$. The closer p

<div align="center" data-full-width="false"><figure><img src="../.gitbook/assets/image (5).png" alt="" width="543"><figcaption><p>In X the ratio total_same/total, in Y the consent. The red curve is the original consent, the blue curve is the adjusted consent.</p></figcaption></figure></div>

***

#### Token yield

The token yield is distributed **at the end of a lock** and depend on the foresight of each lock:

$$
\text{foresight} = \text{lock_amount} \times \text{age_bonus} \times \text{ballot_dissent}_{t_0} \times \text{ballot_consent}_{t_{\text{end}}}
$$

Where:

* $$\text{lock_amount}$$ is the amount of token in the ballot
* $$\text{age_bonus}$$ is the age bonus of the lock, between 1 and 1.25
* $$\text{ballot\_dissent}_{t_0}$$represents how bold the choice was at the time of casting
* $$\text{ballot\_consent}_{t_{\text{end}}}$$represents how well the ballot aligns with the final consensus:

The reward for a lock is its weighted proportion of foresight, relative to the total foresight of all active locks, multiplied by the total token yield accumulated by all locks:

$$
\text{token_yield}_i = \frac{\text{foresight}_i}{\sum_{j} \text{foresight}_j} \times {\text{total_accumulated_token}}
$$
