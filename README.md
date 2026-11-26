# WinxPerp contracts

Private perpetual futures on Robinhood Chain. Collateral is a shielded Merkle vault; positions are commitments only.

## Layout

- `token/USDW.sol` — $USDW, 6 decimals, 1B supply minted to admin (USDG/USDC-shaped)
- `token/EthUsdwSwap.sol` — testers send Robinhood testnet ETH, receive USDW at $1
- `Vault.sol` — shield / unshield; USDW is primary collateral (id 1), admin can add more
- `PerpEngine.sol` — market open / increase / decrease / close / liquidate / health / epoch funding
- `orders/` — Limit, Stop Market, Take Market, Stop Limit, Take Limit, TWAP
- `admin/` — `Timelock`, `Multisig` (set as owner)
- `oracle/` — `ChainlinkOracleAdapter` (Robinhood), `PythOracleAdapter`, `MockPriceOracle`
- `verifiers/MockVerifier.sol` — replace after `privacy_layer` `pnpm setup`

## Order types

Market is built in. Others are registered at deploy (`Deploy.s.sol` wires them).

| Kind | How |
|---|---|
| Market | `open` / `close` |
| Limit / Stop / Take / Stop Limit / Take Limit | `TriggerOrderModule.place` then `executeOrder` |
| TWAP | `TwapOrderModule.place` then `executeOrder` per slice |

## Collateral ($USDW)

Same unit as [USDG](https://docs.robinhood.com/chain/contracts) (6 decimals, $1). Not Robinhood USDG — our own mint so testers have inventory.

| | |
|---|---|
| Name / symbol | USDW |
| Decimals | 6 |
| Cap | 1,000,000,000 USDW, all minted to admin in the constructor |
| Margin | USDW is **primary** (`collateralId = 1`). Admin `addCollateral` can list more ERC-20s (e.g. USDC). Notes bind the id so tokens cannot be mixed. |
| Tester swap | Send RH testnet ETH to `EthUsdwSwap` (or `swap()`). Rate is admin-set ETH/USD (1e8), default 2000e8 → 1 ETH = 2000 USDW. |

After deploy (not done yet): admin `USDW.transfer(swap, amount)` to seed the faucet, then testers swap ETH → USDW and `approve` + `vault.shield` with `collateralId = 1`.

To add another margin token later (e.g. USDC): `vault.addCollateral(2, usdc, 6, true)`. Shield/unshield that token with `collateralId = 2`. Primary USDW cannot be delisted.

## Admin

Two-step `transferOwnership` / `acceptOwnership`. Point `owner` at `Timelock` (optionally behind `Multisig`) so `listMarket`, `setVerifiers`, pause, etc. are delayed.

Keepers may `publishOi` and `sealEpoch`.

## Privacy tech

Groth16 / BN254. Circuits live in `../privacy_layer`. On-chain tree hashes with keccak until you `setHasher` to Poseidon so roots match the Circom `MerkleProof`.

## Test

```bash
git clone --depth 1 --branch v1.9.6 https://github.com/foundry-rs/forge-std lib/forge-std
forge test -vv
```
