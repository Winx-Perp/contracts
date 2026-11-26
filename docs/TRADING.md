# Trading logic — decisions and GMX map

Formulas come from [gmx-io/gmx-synthetics](https://github.com/gmx-io/gmx-synthetics) (README + `PositionUtils` / `MarketUtils`). We reimplement the math inside our commitment model. We do **not** import GMX storage, GM pools, or public position structs.

## Locked decisions

### Funding — option 3 now, option 1 to ship

GMX funding needs live public long/short OI. Updating OI on every open/close would reveal the last trade’s size. That is incompatible with the commitment scheme.

| | Demo | Ship |
|---|---|---|
| Choice | **No funding applied** | **Epoch-batched funding** |
| What is public | Nothing | One net skew per epoch: `longOi - shortOi` |
| What stays private | Individual size / side | Individual size / side |

Ship path (option 1): over a window of N minutes, traders (or a keeper with many witnesses) prove a *sum* of signed size into an epoch accumulator. At epoch end the contract publishes only that net skew and a GMX-style rate. Close/liquidate then apply `size * (fundingIndex - entryIndex)` in-circuit. That leaks aggregate imbalance, not the last fill.

Option 2 (encrypted OI accumulator) is cleaner and not a weekend build.

If asked: “We use GMX’s funding formula, but only on an epoch skew, never on per-trade OI.”

### Liquidation — health keepers (not self-firing)

Positions are private, so the engine **cannot** watch marks and auto-close. Solution:

1. Trader / delegated keeper posts `updateHealth` (zk proof → public `liquidatable` flag).
2. Any keeper calls `liquidateFromHealth` when the flag is set, **or** when health is stale (`> maxHealthAge`).
3. Circuit proves GMX mm / underwater; `seizedAmount` (margin − leftover) is **public** and paid to `PnlPool`.
4. Admin withdraws seized margin with `PnlPool.withdrawSeized`.

Direct `liquidate` still works for anyone who holds the witness.

### Protocol fee — 0.1% of profits

On close / decrease, the circuit proves `protocolFee = floor(profit × profitFeeBps / 10000)` (default **10 bps = 0.1%**). The engine moves that USDW from the Vault to `PnlPool.feesAccrued`. Admin: `withdrawFees`.

## GMX formulas we take

Sources: [README (funding, increase/decrease)](https://github.com/gmx-io/gmx-synthetics/blob/main/README.md), [`PositionUtils.getPositionPnlUsd`](https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/position/PositionUtils.sol), [`PositionUtils.isPositionLiquidatable`](https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/position/PositionUtils.sol).

Implemented as reference math in `contracts/src/lib/PerpMath.sol`. Circuits enforce the same identities without GMX’s pool-PnL cap or price impact (no GM pool).

### Position PnL (full close)

GMX:

```
positionValue = sizeInTokens * indexPrice
long  pnl = positionValue - sizeInUsd
short pnl = sizeInUsd - positionValue
```

Winx `size` is GMX `sizeInUsd`. Entry is implicit:

```
sizeInTokens = sizeInUsd * PRICE_SCALE / entryPrice
```

which reduces to the circuit identity:

```
pnl = floor(size * |exit - entry| / entry)
```

Partial decrease (not in demo circuits):

```
sizeDeltaInTokens = sizeInTokens * sizeDeltaUsd / sizeInUsd
pnlDelta         = totalPnl * sizeDeltaInTokens / sizeInTokens
```

Increase (not in demo circuits):

```
sizeInUsd    += sizeDeltaUsd
sizeInTokens += sizeDeltaUsd * PRICE_SCALE / executionPrice
collateral   += deposit
```

Average entry is then `sizeInUsd * PRICE_SCALE / sizeInTokens`.

### Liquidation threshold

GMX (ignoring impact/fees we do not charge yet):

```
remainingCollateralUsd = collateralUsd + pnlUsd
liquidatable if
  remainingCollateralUsd <= 0
  OR remainingCollateralUsd < minCollateralUsd          // flat floor; ship-path
  OR remainingCollateralUsd < sizeInUsd * minCollateralFactorForLiquidation
```

Demo circuit: underwater (`pnl > margin` on a loser) OR `equity < size * maintenanceMarginBps / 10000`. That is GMX’s `<= 0` and `minCollateralUsdForLeverage` checks. `maintenanceMarginBps` **is** `minCollateralFactorForLiquidation`.

### Oracle execution

GMX: `ExchangeRouter.createOrder` at time `n`, `OrderHandler.executeOrder` with prices **after** `n`.

Demo: same-tx Pyth mark, reject if `now - publishTime > maxPriceAge` or price ≠ public circuit input.

Ship: store an order commitment at `n`, execute with a later Pyth publish time. Same anti-stale rule, no public size.

### Funding (ship only)

GMX, exponent = 1 (their worked example):

```
imbalance = |longOi - shortOi|
total     = longOi + shortOi
payRate   = fundingFactorPerSecond * imbalance / total     // larger side
recvRate  = -payRate * largerOi / smallerOi                // smaller side
```

Example from GMX: factor `1/50000`, long `$150k`, short `$50k` → longs pay `0.001%/s`, shorts receive `0.003%/s`.

v2.2 note: the amount paid is based on the **paying** side’s size, not the larger side’s size.

We would compute `payRate` from the **epoch’s published skew**, then `fundingIndex += payRate * dt`, applied privately as `size * Δindex`.

### Deliberately not taken

- GM pool / LP as counterparty — our vault is the sole counterparty (vAMM)
- Price impact from pool imbalance — no book and no pool to unbalance
- Borrowing fees — capacity constraint for a public pool; we do not have one
- Capped trader PnL vs pool reserves — no pool token reserves
- Public `Position.Props` — replaced by Poseidon commitments
