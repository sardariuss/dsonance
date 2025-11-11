---
cover: ../.gitbook/assets/towerviewers.webp
coverY: 0
---

# Proof-of-Foresight

The Proof-of-Foresight defines the position rules and reward mechanisms, incentivizing participants to act sincerely and prioritize the establishment of lasting truth.

## System Overview

```mermaid
graph TB
    Start([User Opens Position]) --> Input[Input: Token Amount + Choice True/False]
    Input --> Lock[Lock Tokens in Pool]

    Lock --> CalcHot[Calculate Hotness]
    CalcHot --> CalcDur[Calculate Lock Duration]
    CalcDur --> LockPeriod[Position Locked for Duration]

    Lock --> CalcDiss[Calculate Position Dissent at t₀]
    CalcDiss --> Store[Store Position Data]

    LockPeriod --> Unlock[Lock Period Ends]
    Store --> UpdateCons[Position Affects Consensus Forever via Decay]

    Unlock --> CalcCons[Calculate Position Consent at t_end]
    CalcCons --> CalcFore[Calculate Foresight Score]
    CalcFore --> CalcReward[Calculate APY Reward]
    CalcReward --> Claim[User Claims Rewards]

    style Start fill:#e1f5ff
    style Claim fill:#d4edda
    style CalcFore fill:#fff3cd
    style UpdateCons fill:#f8d7da
```

## Position Lifecycle Flow

```mermaid
sequenceDiagram
    participant User
    participant Protocol
    participant Pool
    participant DurationScaler
    participant RewardSystem

    User->>Protocol: Open Position (amount, choice)
    Protocol->>Pool: Lock Tokens

    Pool->>Pool: Calculate Current Consensus
    Pool->>Pool: Calculate Hotness (weighted sum)
    Pool->>DurationScaler: Get Lock Duration (hotness)
    DurationScaler-->>Pool: duration = a × hotness^log₁₀(b)

    Pool->>Pool: Calculate Position Dissent at t₀
    Pool-->>User: Position Created (locked until date)

    Note over Pool: Position influences consensus<br/>forever via decay weight

    loop Consensus Updates Over Time
        Pool->>Pool: Update Weighted Consensus<br/>C = Σ(decay_i × amount_i^true) / Σ(decay_j × amount_j)
    end

    Note over User,Pool: Lock Period Ends

    User->>RewardSystem: Claim Rewards
    RewardSystem->>Pool: Get Position Consent at t_end
    Pool-->>RewardSystem: consent value
    RewardSystem->>RewardSystem: Calculate Foresight<br/>= amount × dissent_t₀ × consent_t_end
    RewardSystem->>RewardSystem: Calculate APY<br/>= (foresight_i / Σforesight_j) × total_yield
    RewardSystem-->>User: Transfer Rewards
```

## Economic Incentive Model

```mermaid
graph TB
    subgraph Position Opening Mechanics
        A[User Analysis] --> B{Predict Consensus Direction}
        B -->|Contrarian View| C[Open Against Majority<br/>Higher Risk<br/>Higher Dissent]
        B -->|Consensus View| D[Open With Majority<br/>Lower Risk<br/>Lower Dissent]
    end

    subgraph Lock Duration Dynamics
        C --> E[Higher Hotness if Pool Active]
        D --> E
        E --> F[Longer Lock Duration<br/>duration = a × hotness^log₁₀b]
        F --> G[More Skin in the Game]
    end

    subgraph Consensus Evolution
        G --> H[Position Affects Consensus via Decay]
        H --> I{Other Positions Open Over Time}
        I --> J[Consensus Shifts Toward Your View]
        I --> K[Consensus Shifts Against Your View]
    end

    subgraph Reward Distribution
        J --> L[High Consent at t_end<br/>Correct Prediction]
        K --> M[Low Consent at t_end<br/>Wrong Prediction]

        C --> N[High Dissent at t₀]
        D --> O[Low Dissent at t₀]

        N --> P[Calculate Foresight]
        O --> P
        L --> P
        M --> P

        P --> Q[foresight = amount × dissent_t₀ × consent_t_end]
        Q --> R{Foresight Score}
        R -->|High dissent + High consent| S[Maximum Reward<br/>Bold & Correct]
        R -->|Low dissent + High consent| T[Moderate Reward<br/>Safe & Correct]
        R -->|High dissent + Low consent| U[Minimal Reward<br/>Bold & Wrong]
        R -->|Low dissent + Low consent| V[Minimal Reward<br/>Safe & Wrong]
    end

    style C fill:#fdcb6e
    style D fill:#dfe6e9
    style F fill:#74b9ff
    style L fill:#00b894
    style M fill:#fab1a0
    style S fill:#00b894
    style T fill:#55efc4
    style U fill:#ff7675
    style V fill:#636e72
```

## Key Insights

**The Proof of Foresight rewards:**
1. **Boldness** - Taking contrarian positions against the current consensus (high dissent)
2. **Accuracy** - Being aligned with the final consensus when the lock period ends (high consent)
3. **Commitment** - Locking more tokens in popular pools creates longer lock durations, showing confidence

**Best case scenario:** Open a position against the majority (high dissent) that later becomes the consensus (high consent) = Maximum rewards

**Worst case scenario:** Open a position that ends up misaligned with the final consensus = Minimal/no rewards

This creates a natural incentive for participants to:
- Research and form genuine predictions
- Act early when they have conviction (higher dissent opportunities)
- Contribute to establishing lasting truth over time



