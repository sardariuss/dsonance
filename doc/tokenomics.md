---
cover: .gitbook/assets/towerviewers.webp
coverY: 0
---

# Tokenomics

Towerview operates with three tokens:

* **ckUSDT**: The supply token, used for opening positions and earning yield.
* **ckBTC**: The collateral token, used to secure the lending system.
* **TWV**: The native governance token of Towerview.

### **USDT/BTC Lending Mechanism**

Towerview uses a lending model similar to AAVE, where the lending and borrowing APY depend on the utilization rate. Users can supply ckUSDT by locking ckUSDT in positions, and borrow ckUSDT against ckBTC. ckBTC is used as collateral and liquidated in case the LTV increased above the liquidation threshold.

While the users's borrow APY depends solely on the utilization rate, his supply APY depends on his performance in accuretly predicting the consensus on the topic he participates, as framed by the proof-of-foresight mechanism.

### **TWV Token**

The TWV token serves as governance token for the Towerview platform:

* **Mining** – Distributed to suppliers, borrowers and pool creators based on their performance.
* **Burn** – Required to open new pools; buy-back and burn TWV using platform lending fees.
* **Governance** – Locked in neurons, enabling participation in decisions shaping the future of Towerview.

The minting of TWV rewards follows an **exponential decay model** with a **4-year half-life**. Early users earn more, while emissions gradually decrease, ensuring long-term scarcity and sustainability.

### **Supply Dynamics & Deflationary Mechanisms**

The TWV token follows a **two-phase economic model**:

1. **Inflationary Phase** – Initially, TWV rewards will be abundant, and burn requirements will be minimal to encourage adoption.
2. **Deflationary Phase** – Over time, TWV rewards will decrease, while burning requirements will increase, leading to a progressively scarcer supply.

To reinforce this deflationary shift, platform lending fees will be used to buy back and burn TWV tokens. This ongoing reduction in supply supports long-term value appreciation and ecosystem sustainability.

#### **TWV Initial Token Allocation**

<figure><img src=".gitbook/assets/image (8).png" alt=""><figcaption></figcaption></figure>

The total supply of TWV will be **100 million tokens** distributed as follows:

* **6M TWV (6%) – Core Builder Seed**\
  Initial allocation to the founding developer, recognizing early work and providing runway to continue building.
* **9M TWV (9%) – Governance Bootstrap (SNS Swap)**\
  Allocated for the SNS decentralization swap, ensuring early community participation and a decentralized platform.
* **9M TWV (9%) – Community Treasury**\
  Reserved for future initiatives such as ecosystem grants, partnerships, liquidity, and strategic growth, under the control of SNS governance.
* **9M TWV (9%) – Core Builder Vesting Pool**\
  A vesting pool reserved for the core builder, gradually unlocked through SNS governance proposals to align long-term incentives.
* **67M TWV (67%) – User Mining Rewards**\
  Distributed to users over time as incentives for participation (for opening positions and borrowing), following a halving-based emission model to sustain engagement and growth.
