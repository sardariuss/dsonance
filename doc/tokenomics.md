# Tokenomics

The platform uses two tokens:

* The **ckBTC token**, the wrapped version of **BTC** for the Internet Computer.
* The **DSN token**, the native **Dsonance utility and governance token**

### ckBTC token

ckBTC is a token on the **Internet Computer (ICP)** blockchain that represents **Bitcoin (BTC) in a wrapped form**. It allows users to transact BTC **quickly and cheaply** within the Internet Computer ecosystem while still being **fully backed 1:1 by real Bitcoin**.

{% hint style="info" %}
Since ckBTC is backed 1:1 by BTC and secured by chain-key cryptography, it effectively functions as BTC. Therefore, both terms are used interchangeably throughout this documentation, even though, in practice, the Dsonance platform specifically uses ckBTC.
{% endhint %}

BTC serves multiple functions:

* Input: required to participate (vote) in order to shape consensus
* Incentive: BTC yield to reward voters which past vote aligns with current consensus
* Borrowed: to be borrowed against DSN tokens

### DSN token

The DSN token is the **native utility and governance token** of the Dsonance platform. It grants holders the power to shape the future of the platform through the **Dsonance DAO**, influencing key decisions and protocol upgrades.

DSN serves multiple functions:

* **Rewards:** Distributed to users who actively participate in the platform.
* **Burn Mechanism:** Users must burn DSN to engage in certain platform activities.
* **Collateral:** Used as collateral for borrowing BTC.

#### **BTC Yield Mechanism in Dsonance**

Dsonance generates BTC yield by enabling users to **borrow BTC against their DSN tokens**. The borrowed BTC comes from **ballot-locked funds**, effectively turning the voting process into a decentralized lending protocol.

To maintain a balanced market, Dsonance implements a **utilization-based interest rate model**, dynamically adjusting borrowing and lending rates based on supply and demand—similar to established DeFi platforms like **Aave and Compound**.

Additionally, a **ckBTC/DSN liquidity pool** will be **bootstrapped using a portion of the ICP treasury from the SNS swap**, ensuring sufficient liquidity and price stability. This pool will also allow the protocol to **sell DSN collateral when necessary**, mitigating risks and securing the system's long-term sustainability.

#### **BTC Buyback & Burn**

From launch, the platform will allocate **10% of the BTC yield** it generates to **buy back and burn DSN tokens**. This continuous burn mechanism helps reduce supply, driving long-term value appreciation.

By combining **early incentives** with a **gradual shift toward scarcity**, these mechanisms encourage early adoption while empowering the long-term value growth of DSN.

#### Supply Dynamics

The DSN tokenomics follow a **two-phase model**:

1. **Inflationary Phase** – Initially, DSN rewards will be abundant, while burn requirements remain low.
2. **Deflationary Phase** – Over time, rewards will decrease and burning costs will rise, leading to a scarcer supply.

#### **DSN Token Allocation**

<figure><img src=".gitbook/assets/token_allocation.PNG" alt=""><figcaption></figcaption></figure>

The total supply of DSN will be **1 billion tokens**, distributed as follows to ensure long-term sustainability and alignment with ecosystem growth:

* **160 million DSN (16%) – Dev team**\
  Reserved as a **reward and incentive for the development team** for their contributions to the project.
* **230 million DSN (23%) – SNS Decentralization Swap**\
  Allocated for the SNS swap, ensuring broad community ownership and decentralized governance.
* **105 million DSN (10.5%) – Treasury**\
  Held in reserve for future initiatives, partnerships, ecosystem grants, and unforeseen needs.
* **5 million DSN (0.5%) – Airdrop**\
  A small portion dedicated to initial distribution, rewarding early adopters and fostering community engagement while minimizing the risk of excessive sell pressure.
* **500 million DSN (50%) – Protocol Rewards**\
  Gradually distributed to users over time as incentives for participating in the network, following an **exponential halving model every four years**, ensuring long-term engagement and sustainable growth.

