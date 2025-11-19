# Proof-of-Foresight: Game Resistance Analysis

## Overview

The proof-of-foresight mechanism is designed to reward users who correctly align with future consensus. Unlike traditional prediction markets, it operates as a **continuous consensus mechanism** where positions lock for dynamic durations and each position has its own individual arbitration date.

## How Proof-of-Foresight Works

### Core Mechanics

1. **Continuous Positioning**: Users can add positions to any pool at any time. There are no fixed voting windows - the system operates continuously.

2. **Dynamic Lock Duration**: When placing a position, users see the current lock duration based on current hotness. This is the **minimum** lock duration - it can only increase as more positions are added "around" the same time period.

3. **Individual Arbitration Dates**: Each position has its own unlock/arbitration date calculated as:
   ```
   arbitration_date = position_timestamp + lock_duration
   ```
   Different positions in the same pool can unlock at completely different times.

4. **APY Calculation**: The APY for a position depends on two factors:
   - **Dissent at creation** (`dissent_t0`): How contested the pool was when the position was opened
   - **Consent at unlock** (`consent_t_unlock`): How well the position aligns with pool consensus at arbitration

   ```
   APY = f(dissent_t0, consent_t_unlock)
   ```

   **Critical detail**: What matters is the consent at the moment of unlock, not during the lock period. A position with great consent throughout the lock but poor consent just before unlock will have very low APY.

5. **The Risk of Being "Right Too Soon"**: If you correctly predict the truth but the market takes longer to discover it than your lock duration, your position unlocks before consensus forms, resulting in low APY despite being ultimately correct.

### Hotness and Lock Duration

The lock duration is determined by the "hotness" of the pool at the position's timestamp. Hotness is calculated using a weighted sum of surrounding positions with exponential decay:

```
hotness_i = amount_i
          + Σ(j < i) { (decay_j / decay_i) × amount_j }
          + Σ(j > i) { (decay_i / decay_j) × amount_j }
```

Where the decay function is:
```
decay(t) = exp(λ × (t - genesis_time))
λ = ln(2) / half_life
```

The lock duration is then computed using a power scaling function:
```
duration = a × hotness^(log₁₀(b))
```

**Key properties**:
- Earlier positions contribute to later ones with diminishing weight
- Newer positions have retroactive impact on older ones, also with diminishing weight
- The exponential decay creates a natural "around" window - positions far apart in time barely affect each other
- Lock durations extend naturally when pools gain traction over time

## Game Resistance: The Whale Doubling-Down Scenario

### The Attack Scenario

Consider two opposing whales attempting to manipulate consensus through repeated capital injections:

**Setup**:
- Whale A has a position on Side X unlocking at time T₀ + duration₀
- Whale B has a position on Side Y unlocking at time T₀ + duration₀
- Current consensus favors one side, giving the other low expected APY
- Both whales attempt to manipulate by "doubling down" - adding new positions just before their original positions unlock

**Attack Strategy**:
1. Just before unlock, the losing whale adds a massive new position to flip consensus in their favor
2. This increases hotness, extending all locked positions' durations
3. The winning whale responds by adding their own position to maintain consensus
4. Both whales keep doubling down indefinitely, creating an escalating capital war

**Intended Outcome**:
- Manipulate consensus at will through capital injection
- Maximize APY for original positions by controlling final consensus
- Force opponents into longer locks than anticipated

### Why This Attack Fails

#### 1. Exponential Decay Creates Convergence

When a whale adds a new position at time T_n to influence their original position at T₀:

```
contribution_to_original_hotness = amount × (decay_T_n / decay_T₀)
                                 = amount × exp(-λ × (T_n - T₀))
```

Since `T_n > T₀` and `λ > 0`, each successive round contributes **exponentially less** to the original position's hotness.

**Round 1**: Add 1000 USDT at T₁ = T₀ + duration₀
- Contribution: `1000 × exp(-λ × duration₀)`

**Round 2**: Add 1000 USDT at T₂ = T₀ + duration₁ (where duration₁ > duration₀ due to round 1)
- Contribution: `1000 × exp(-λ × duration₁)`
- Since duration₁ > duration₀, this contribution is **smaller** than round 1

**Round n**:
- Contribution: `1000 × exp(-λ × duration_{n-1})`
- Diminishing exponentially with each round

The total added hotness forms a geometric series:
```
Σ amount × exp(-λ × duration_n)
```

With ratio `r = exp(-λ × Δt) < 1`, this series **converges to a finite value**.

**Result**: The lock duration **stabilizes** at some finite arbitration date, even with infinite doubling-down attempts.

#### 2. Symmetric Costs for Both Sides

Both whales face identical consequences:
- Both lock additional capital with each round
- Both experience the same exponentially diminishing returns
- Both positions extend by the same amounts
- Neither gains a systematic advantage

The war of attrition depends purely on:
- Who runs out of capital first
- Who is willing to lock capital longer
- Who is actually correct about the ultimate truth

#### 3. Increasing Dissent = Higher Stakes

Each round of doubling down increases the pool's dissent (contested capital on both sides). This has two effects:

**For the eventual winner**:
- Higher dissent₀ increases potential APY
- Makes the final consensus victory more profitable

**For the eventual loser**:
- Higher dissent₀ would have increased their APY too
- Losing becomes more painful with more capital at stake

The escalation raises stakes symmetrically without providing a manipulation advantage.

#### 4. The Consent Timing Problem

The APY depends critically on `consent_t_unlock` - the consensus at the moment of arbitration. This creates a fundamental problem for manipulators:

**Scenario**: Whale A's original position unlocks at T_unlock after multiple doubling rounds
- At T_unlock, consensus must favor Side X for good APY
- But Whale A has been injecting capital throughout, visible to all participants
- Other participants can see the manipulation attempt and:
  - Add their own positions timed to unlock at T_unlock
  - Place limit orders to trigger at specific consensus ratios
  - Front-run the final moments before T_unlock

**The manipulator cannot control consensus at the exact arbitration moment** because:
- Their capital injections are public and visible
- Counter-parties can time positions to the same arbitration date
- The final consensus at T_unlock depends on all participants' actions
- Being "right" at T_unlock requires actual truth alignment, not just capital

#### 5. Lock Duration Uncertainty Compounds Risk

While whales can see the *minimum* lock duration when adding positions, they cannot predict:
- How much the duration will extend due to future activity
- When exactly their position will unlock
- What the consensus will be at that future unknown time
- How much total capital they'll need to commit

Each doubling round:
- Extends locks unpredictably (due to opponent's simultaneous actions)
- Requires more capital than anticipated
- Pushes arbitration further into an uncertain future
- Increases exposure to truth discovery events

#### 6. The Self-Limiting Nature of Position Influence

The exponential decay weighting means:
- Positions only significantly influence "nearby" positions in time
- Trying to influence positions far in the future requires exponentially more capital
- The natural "around" window created by decay prevents extreme manipulation
- As arbitration dates get pushed further, new positions have less and less impact

**Mathematical limit**: Even with infinite capital, the lock duration converges to a finite maximum due to the geometric series convergence.

### Outcome: A War Nobody Can Win Through Capital Alone

If two whales truly engage in infinite doubling-down with equal capital:

1. **Lock durations converge** to a finite arbitration date due to exponential decay
2. **Final APY depends on truth** at that arbitration date, not capital deployed
3. **Both whales have locked massive capital** for extended periods
4. **The winner is determined by actual consensus** at T_unlock, not manipulation
5. **Expected value is negative** for manipulators due to capital costs and uncertainty

The proof-of-foresight mechanism transforms manipulation attempts into:
- Increased pool liquidity (more locked capital)
- Higher stakes (more dissent)
- Longer-term commitments (extended locks)
- But **not** into systematic advantage for the manipulator

## Other Gaming Scenarios Considered

### Arbitration Date Sniping

**Attack**: Monitor large positions nearing unlock and add opposing positions to flip consensus at the last moment.

**Why it fails**:
- Original position holder can counter-snipe
- Your position also locks, creating symmetric risk
- Increases hotness, extending all positions including your own
- Still requires being correct about truth at arbitration
- Limit orders can defend against sniping automatically

### Time-of-Check Time-of-Use

**Attack**: Monitor pending positions to see where hotness is building, then front-run with optimal timing.

**Why it fails**:
- Your own position contributes to hotness, changing the calculation
- Other participants can do the same, creating competition
- Still requires correct truth prediction
- On ICP, deterministic finality makes traditional front-running difficult

### Truth Discovery Front-Running

**Attack**: Monitor external information sources and immediately position when new information emerges.

**Why it fails**:
- This is actually **intended behavior** - rewarding quick truth discovery
- Your position contributes to hotness, so others aren't far behind
- If wrong about truth, you still lose
- Being fast and informed is legitimate participation, not gaming

### Insider Trading

**Attack**: Use privileged information to position with certainty about future outcomes.

**Why it fails**:
- This isn't a flaw in proof-of-foresight specifically
- It's a general problem with any prediction or consensus market
- Illegal in traditional markets
- The mechanism itself cannot prevent this (nor can most systems)

## Conclusion: Why Proof-of-Foresight Cannot Be Gamed

The proof-of-foresight mechanism is fundamentally game-resistant because:

1. **Exponential Decay Creates Natural Convergence**: The hotness weighting ensures that manipulation attempts become self-limiting through geometric series convergence.

2. **Symmetric Information and Costs**: All participants see the same data and face the same costs. There's no asymmetric advantage from capital manipulation.

3. **Truth Alignment is Required**: APY depends on being aligned with consensus at the specific arbitration moment, which cannot be reliably manipulated with capital alone.

4. **Lock Duration Uncertainty**: Participants cannot predict final lock durations, making strategic timing extremely difficult.

5. **The "Right Too Soon" Risk**: Even correct predictions can fail if consensus forms too slowly, making timing as important as correctness.

6. **Consent Timing Criticality**: Only the final consensus at unlock matters for APY, not consensus during the lock period, preventing temporary manipulation.

7. **Manipulation Becomes Participation**: Attempts to game the system through capital injection simply become another form of legitimate participation with symmetric risks and rewards.

The mechanism successfully transforms the problem of prediction into a problem of **consensus alignment over time**, where being right at the right moment matters more than having the most capital. Any attempt to manipulate through repeated capital injection faces exponentially diminishing returns and converges to a scenario where truth, not capital, determines the outcome.
