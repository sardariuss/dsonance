---
cover: .gitbook/assets/towerviewers.webp
coverY: 0
---

# TWV Mining

Towerview includes a sophisticated mining mechanism that distributes TWV tokens to protocol participants. This system rewards both suppliers and borrowers who contribute to the lending protocol's.

## Overview

TWV mining operates on a continuous emission schedule with exponential decay, similar to Bitcoin's halving mechanism but with smooth mathematical curves. The system automatically distributes newly minted TWV tokens to active protocol participants based on their proportional contribution to the protocol's total supply and borrow amounts.

## Emission Mechanics

### Mathematical Model

The TWV emission follows an exponential decay model based on three key parameters:

- **`emission_total_amount_e8s`**: The total maximum TWV tokens that will ever be minted
- **`emission_half_life_s`**: The half-life period in seconds for the emission curve
- **`borrowers_share`**: The percentage of emissions allocated to borrowers (remainder goes to suppliers)

The emission rate at any given time is calculated using the formula:

```
Amount to mint = E₀ * (e^(-k*t₁) - e^(-k*t₂))
```

Where:
- `E₀` = Total emission amount
- `k = ln(2) / half_life` (decay constant)
- `t₁` = Time since last mint
- `t₂` = Current time

## Distribution Logic

### Borrowers vs Suppliers Split

The `borrowers_share` parameter determines the percentage of each emission that goes to borrowers versus suppliers:

```motoko
let borrowers_amount = amount_to_mint * parameters.borrowers_share;
let suppliers_amount = amount_to_mint * (1.0 - parameters.borrowers_share);
```

For example, with `borrowers_share = 0.75`:
- 75% of emissions go to borrowers
- 25% of emissions go to suppliers

### Individual Share Computation

#### Supplier Shares

Each supplier's share is calculated proportionally based on their supplied amount relative to the total protocol supply:

```motoko
let supplied = Float.fromInt(supply_position.supplied);
let share = supplied / raw_supplied;
let participation_amount = total_amount * share;
```

**Example**: If Alice has supplied 10,000 USDT and the total protocol supply is 100,000 USDT, Alice receives 10% of the supplier emissions.

#### Borrower Shares  

Each borrower's share is calculated proportionally based on their borrowed amount relative to the total protocol borrows:

```motoko
let borrowed = borrow.raw_amount;
let share = borrowed / raw_borrowed;
let participation_amount = total_amount * share;
```

**Example**: If Bob has borrowed 5,000 USDT and the total protocol borrows are 50,000 USDT, Bob receives 10% of the borrower emissions.

## Economic Implications

The TWV mining system creates several important economic dynamics:

1. **Early Participation Incentive**: Higher emission rates early in the protocol's life encourage early adoption
2. **Sustained Engagement**: Continuous emissions reward ongoing protocol participation
3. **Proportional Rewards**: Larger participants receive proportionally larger rewards
4. **Balanced Incentives**: The borrowers/suppliers split ensures both sides of the market are incentivized

This mining mechanism helps bootstrap network effects by rewarding the most valuable protocol participants with governance tokens, aligning long-term incentives between users and the protocol's success.