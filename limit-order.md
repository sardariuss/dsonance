# Limit Order Feature

## Overview

Limit orders in the Dsonance protocol allow users to place conditional positions that automatically execute when a pool's dissent reaches a specified threshold. Unlike traditional limit orders based on price, these are **dissent-based limit orders** that trigger when the pool's disagreement metric reaches a target level.

## Key Concepts

### What is a Limit Order?

A limit order is a pending position placement that:
1. **Waits** for the pool dissent to reach a user-specified threshold
2. **Automatically executes** when triggered, creating a locked position
3. **Accumulates base supply APY** while waiting (incentivizing users to place limit orders)
4. **Transitions to a locked position** when executed, following the standard proof-of-foresight mechanics
5. **Auto-converts to supply** when the position unlocks, continuing to earn base supply APY

### Dissent-Based Triggering

- **Traditional limit orders**: "Buy when price reaches $X"
- **Dsonance limit orders**: "Place position when pool dissent for my choice reaches X%"

This aligns with the protocol's proof-of-foresight mechanism where dissent measures how contrarian a position is.

## Lifecycle of a Limit Order

### Phase 1: Pending (Earning Base Supply APY)

**State**: LimitOrder
**Location**: Pool's limit order queue
**User benefit**: Earns base supply APY on the amount

When a user places a limit order:
```motoko
{
  limit_order_id: UUID;
  pool_id: UUID;
  choice: YesNoChoice;  // YES or NO
  amount: Nat;          // USDT amount
  target_dissent: Float; // Trigger threshold (0.0 to 1.0)
  placed_at: Nat;       // Timestamp
  supply_index_at_placement: Float; // For tracking accrued interest
}
```

**Interest Accrual**:
- The `amount` earns the protocol's base supply APY
- Interest compounds using the supply index mechanism
- This makes limit orders financially attractive vs. waiting to manually place positions

### Phase 2: Triggered (Converting to Locked Position)

**Trigger Condition**: When `pool.dissent_for_choice >= limit_order.target_dissent`

**Execution Process**:
1. Calculate accrued supply interest since placement
2. Add accrued interest to the original amount
3. Create a new locked position with the total amount (original + interest)
4. Remove limit order from the queue
5. Apply standard proof-of-foresight mechanics:
   - Position dissent calculated at execution time
   - Position consent tracked via rolling timeline
   - Lock duration computed based on pool hotness
   - Foresight rewards calculated based on dissent/consent

### Phase 3: Locked Position (Variable APY via Proof-of-Foresight)

**State**: Position (locked)
**Location**: Pool's position register
**User benefit**: Earns variable APY based on foresight quality

The position now follows standard position behavior:
- **Lock duration**: Computed by DurationScaler based on pool hotness
- **APY calculation**: Variable, based on proof-of-foresight formula
  - Higher dissent at placement → Higher potential APY
  - Higher final consent (agreement over time) → Higher realized APY
  - Formula: `foresight_reward = f(dissent, final_consent)`
- **Position value grows** during lock period based on realized APY

### Phase 4: Unlocked (Auto-Convert to Supply)

**Trigger**: Lock duration expires (`current_time >= position.lock.release_date`)

**Resolution Process**:
1. Calculate final position value (original amount + foresight rewards)
2. **Automatically add to user's supply balance** in the lending pool
3. User does NOT need to claim or connect
4. The supplied amount immediately starts earning base supply APY again
5. User can withdraw their supply at any time (subject to lending pool utilization)

**User Experience**:
- User places limit order → forgets about it
- Limit order executes when dissent reached → automatic
- Position unlocks after duration → automatic supply
- Supply earns APY continuously → automatic
- User connects weeks later → sees accumulated value

## Interest Accrual Mechanisms

### Three APY Streams

1. **Base Supply APY (Phase 1 & 4)**
   - Applied to: Pending limit orders + Auto-converted supply
   - Rate: Protocol's base supply rate (varies with utilization)
   - Mechanism: Supply index tracks compounding interest
   - Continuous: Never stops earning

2. **Proof-of-Foresight APY (Phase 3)**
   - Applied to: Locked positions only
   - Rate: Variable based on dissent/consent quality
   - Mechanism: Foresight calculation at unlock time
   - Time-limited: Only during lock period

3. **Combined Return**
   - Total return = Base APY (Phase 1) + Foresight APY (Phase 3) + Base APY (Phase 4)
   - Compounds automatically across all phases
   - No manual claiming required

### Supply Index Tracking

**Purpose**: Track interest accrual without iterating over all limit orders

**How it works**:
```motoko
// At limit order placement
limit_order.supply_index_at_placement = current_supply_index;

// At limit order execution (trigger)
accrued_interest = amount * (current_supply_index / supply_index_at_placement - 1.0);
total_amount_for_position = amount + accrued_interest;
```

**Supply index updates**:
- Increases continuously based on borrow interest and utilization
- Updated via the lending pool's Indexer module
- Same mechanism used for regular supply positions

## Implementation Details

### State Structure (in 00-02-00-renamings/Types.mo)

```motoko
public type LimitOrder = {
  limit_order_id: UUID;
  pool_id: UUID;
  choice: YesNoChoice;
  amount: Nat;
  target_dissent: Float;
  placed_at: Nat;
  supply_index_at_placement: Float;
  from: Account;
};

public type LimitOrderQueue = {
  orders: Map<UUID, LimitOrder>;
  by_pool: Map<UUID, Set<UUID>>;  // pool_id -> set of limit_order_ids
  by_account: Map<Account, Set<UUID>>;  // account -> set of limit_order_ids
};
```

### Key Functions

#### Controller.mo

```motoko
public func put_limit_order(args: PutLimitOrderArgs) : async* Result<LimitOrder, Text>
```
- Validates target dissent (must be > current dissent)
- Transfers USDT from user to protocol
- Records current supply index
- Adds to limit order queue

```motoko
public func check_and_execute_limit_orders(pool_id: UUID) : async* ()
```
- Called after each position placement (which changes dissent)
- Iterates through pending limit orders for the pool
- Executes any orders where `current_dissent >= target_dissent`

#### PoolController.mo

```motoko
public func execute_limit_order(
  pool: Pool<A, B>,
  limit_order: LimitOrder,
  current_supply_index: Float,
) : Position<B>
```
- Calculates accrued supply interest
- Creates locked position with total amount
- Computes dissent, lock duration, foresight tracking
- Returns new position

```motoko
public func resolve_unlocked_positions(pool_id: UUID) : async* ()
```
- Identifies positions with expired locks
- Calculates final foresight rewards
- Adds final amount to user's supply balance
- Removes position from active positions

## Financial Incentive Analysis

### Why Place Limit Orders vs. Manual Timing?

**Limit Order Advantages**:
1. **Earn while waiting**: Base supply APY on pending amount
2. **No monitoring needed**: Automatic execution
3. **Capture foresight upside**: Executes at target dissent level
4. **Auto-compound**: Position → Supply conversion is automatic
5. **Never stop earning**: Continuous APY from placement through unlock

**Manual Placement**:
- Requires active monitoring
- Misses base APY during waiting period
- Risk of missing optimal dissent timing
- Requires manual claiming after unlock

### Expected Return Calculation

```
Total Return =
  (Base APY × Waiting Time) +
  (Foresight APY × Lock Time) +
  (Base APY × Post-Unlock Time)
```

**Example scenario**:
- User places 1000 USDT limit order, target dissent = 0.7
- Waiting period: 10 days @ 5% base APY → ~1.37 USDT earned
- Trigger executes: 1001.37 USDT locked position
- Lock period: 30 days @ 15% foresight APY → ~12.31 USDT earned
- Post-unlock: 1013.68 USDT earning 5% base APY indefinitely

## Edge Cases and Considerations

### 1. Multiple Limit Orders at Same Dissent

**Behavior**: FIFO execution (oldest first)

**Rationale**: Fair to early limit order placers

### 2. Dissent Never Reaches Target

**Behavior**: Limit order remains pending indefinitely

**User action**: Can cancel and withdraw funds + accrued interest

### 3. Pool Activity Stalls After Trigger

**Behavior**: Position remains locked until duration expires

**Then**: Auto-converts to supply as designed

### 4. Rapid Dissent Changes

**Problem**: Dissent could spike above target, then drop

**Solution**: Use rolling average or require dissent to be sustained for N blocks

**Current**: Simple threshold (may trigger on temporary spike)

### 5. Gas/Cycle Costs for Checking

**Problem**: Checking limit orders after every position placement could be expensive

**Solutions**:
- Only check limit orders in same direction as new position
- Batch execute multiple limit orders in single call
- Use heartbeat timer to periodically check all pools

### 6. Supply Pool Liquidity

**Problem**: Auto-converted supply might exceed available liquidity for withdrawal

**Behavior**: Standard lending pool rules apply:
- Withdrawals limited by utilization ratio
- Users can withdraw proportional to available liquidity
- Interest continues accruing while waiting

## Integration Points

### Lending Pool Integration

**Supply Index**:
- Limit orders use the same supply index as regular lenders
- Interest calculation is identical
- No special handling needed

**Auto-Conversion**:
- When position unlocks, call `supply()` on behalf of user
- Use position's final amount as supply amount
- Update user's supply balance in lending registry

### Proof-of-Foresight Integration

**Dissent Calculation**:
- Executed limit order position uses dissent at execution time
- Not dissent at placement time
- This is correct: foresight is about predicting future consensus

**Lock Duration**:
- Computed using DurationScaler with pool hotness at execution
- Not at limit order placement
- Reflects actual pool activity when position created

### Event System

**Events to Emit**:
1. `LimitOrderPlaced` - When user creates limit order
2. `LimitOrderExecuted` - When dissent threshold reached
3. `PositionAutoUnlocked` - When position lock expires
4. `SupplyAutoAdded` - When unlocked position converts to supply
5. `LimitOrderCanceled` - If user cancels pending order

## Testing Considerations

### Unit Tests

1. **Interest accrual**: Verify supply index calculations
2. **Trigger logic**: Test dissent threshold detection
3. **Auto-conversion**: Ensure position → supply works correctly
4. **Cancellation**: Test withdrawal with accrued interest

### Integration Tests

1. **Full lifecycle**: Place → Execute → Lock → Unlock → Supply
2. **Multiple orders**: FIFO execution order
3. **Edge cases**: Dissent fluctuations, pool inactivity
4. **Gas costs**: Measure execution costs at scale

### Scenario Tests

1. **Happy path**: User places order, gets triggered, earns returns
2. **Never triggered**: User cancels after waiting period
3. **Rapid execution**: Trigger happens immediately after placement
4. **Long wait**: Order pending for months before trigger

## Migration Considerations

Since this is a new feature being added in migration 00-02-00-renamings:

1. **State addition**: Add `limit_order_queue` to protocol State
2. **No data migration needed**: Fresh start, no existing limit orders
3. **Backward compatible**: Doesn't affect existing positions or supply

## Summary

Limit orders transform passive waiting into active earning:
- **Phase 1**: Earn base APY while waiting for trigger
- **Phase 2**: Execute automatically when dissent reached
- **Phase 3**: Earn variable foresight APY while locked
- **Phase 4**: Auto-convert to supply, earn base APY forever

This creates a "set and forget" user experience where funds are always productive, always earning, and require no manual intervention beyond the initial placement.
