---
cover: .gitbook/assets/logo.png
coverY: 0
---

# Tokenomics

Dsonance operates with three tokens:

* **ckUSDT**: The supply token, used for voting and earning yield.
* **ckBTC**: The collateral token, used to secure the lending system.
* **DSN**: The native utility and governance token of Dsonance.

### **USDT/BTC Lending Mechanism**

Dsonance uses a lending model similar to AAVE, where the lending and borrowing APY depend on the utilization rate. Users can supply ckUSDT by locking ckUSDT in ballots, and borrow ckUSDT against ckBTC. ckBTC is used as collateral and liquidated in case the LTV increased above the liquidation threshold.

While the users's borrow APY depends solely on the utilization rate, his supply APY depends on his performance in accuretly predicting the consensus on the topic he participates, as framed by the proof-of-foresight mechanism.

### **DSN Token**

The DSN token serves as a utility and governance token for the Dsonance platform:

* **Rewards** – Distributed to vote authors, voters, borrowers, and liquidity providers.
* **Burn Mechanism** – Required to open new votes.
* **Governance** – Locked in neurons, enabling participation in decisions shaping the future of Dsonance.

The minting of DSN rewards follows an **exponential decay model** with a **4-year half-life**. Early users earn more, while emissions gradually decrease, ensuring long-term scarcity and sustainability.

### **Supply Dynamics & Deflationary Mechanisms**

The DSN token follows a **two-phase economic model**:

1. **Inflationary Phase** – Initially, DSN rewards will be abundant, and burn requirements will be minimal to encourage adoption.
2. **Deflationary Phase** – Over time, DSN rewards will decrease, while burning requirements will increase, leading to a progressively scarcer supply.

To reinforce this deflationary shift, platform lending fees will be used to buy back and burn DSN tokens. This ongoing reduction in supply supports long-term value appreciation and ecosystem sustainability.

#### **DSN Token Allocation**

<figure><img src=".gitbook/assets/image (8).png" alt=""><figcaption></figcaption></figure>

The total supply of DSN will be **10 million tokens** distributed as follows:

* **600k DSN (6%) – Core Builder Seed**\
  Initial allocation to the founding developer, recognizing early work and providing runway to continue building.
* **900k DSN (9%) – Governance Bootstrap (SNS Swap)**\
  Allocated for the SNS decentralization swap, ensuring early community participation and a decentralized platform.
* **900k DSN (9%) – Community Treasury**\
  Reserved for future initiatives such as ecosystem grants, partnerships, liquidity, and strategic growth, under the control of SNS governance.
* **900k DSN (9%) – Core Builder Vesting Pool**\
  A vesting pool reserved for the core builder, gradually unlocked through SNS governance proposals to align long-term incentives.
* **6.7 million DSN (67%) – User Mining Rewards**\
  Distributed to users over time as incentives for participation (for voting and borrowing), following a halving-based emission model to sustain engagement and growth.
