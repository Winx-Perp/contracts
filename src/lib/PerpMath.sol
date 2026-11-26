// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice GMX v2 formulas reimplemented for WinxPerp (no GMX storage).
/// See docs/TRADING.md. Prices are 1e8 (Pyth), not GMX's 1e30.
///
/// Demo does not call funding. Epoch batching would pass a published skew
/// into fundingRatePerSecond, then apply size * Δindex inside the circuit.
library PerpMath {
    uint256 internal constant PRICE_SCALE = 1e8;
    uint256 internal constant BPS_DENOM = 10_000;

    error InvalidPrice();
    error InvalidSize();

    /// GMX PositionUtils.getPositionPnlUsd for a full close, uncapped.
    /// sizeUsd is GMX sizeInUsd; entryPrice defines sizeInTokens.
    function positionPnlUsd(uint256 sizeUsd, bool isLong, uint256 entryPrice, uint256 indexPrice)
        internal
        pure
        returns (int256 pnl)
    {
        if (entryPrice == 0 || indexPrice == 0) revert InvalidPrice();
        if (sizeUsd == 0) revert InvalidSize();

        // sizeInTokens = sizeUsd * PRICE_SCALE / entryPrice
        // positionValue = sizeInTokens * indexPrice / PRICE_SCALE
        //               = sizeUsd * indexPrice / entryPrice
        uint256 positionValue = (sizeUsd * indexPrice) / entryPrice;
        if (isLong) {
            pnl = int256(positionValue) - int256(sizeUsd);
        } else {
            pnl = int256(sizeUsd) - int256(positionValue);
        }
    }

    /// Circuit identity: floor(size * |exit - entry| / entry), signed.
    function linearPnl(uint256 sizeUsd, bool isLong, uint256 entryPrice, uint256 exitPrice)
        internal
        pure
        returns (int256)
    {
        return positionPnlUsd(sizeUsd, isLong, entryPrice, exitPrice);
    }

    function equityUsd(uint256 marginUsd, int256 pnl) internal pure returns (uint256) {
        int256 equity = int256(marginUsd) + pnl;
        return equity > 0 ? uint256(equity) : 0;
    }

    /// GMX isPositionLiquidatable without price impact / close fees.
    /// mmBps is minCollateralFactorForLiquidation (e.g. 100 = 1%).
    function isLiquidatable(uint256 remainingCollateralUsd, uint256 sizeUsd, uint32 mmBps)
        internal
        pure
        returns (bool)
    {
        if (remainingCollateralUsd == 0) return true;
        uint256 minCollateralForLeverage = (sizeUsd * mmBps) / BPS_DENOM;
        return remainingCollateralUsd < minCollateralForLeverage;
    }

    /// GMX funding (exponent = 1), from README worked example.
    /// Returns signed rate per second in PRICE_SCALE units (1e8 = 100%).
    /// Positive => longs pay. Only used once an epoch publishes skew.
    function fundingRatePerSecond(uint256 longOiUsd, uint256 shortOiUsd, uint256 fundingFactorPerSecond)
        internal
        pure
        returns (int256 payRateLongs, int256 payRateShorts)
    {
        uint256 total = longOiUsd + shortOiUsd;
        if (total == 0 || fundingFactorPerSecond == 0) return (0, 0);

        uint256 imbalance = longOiUsd > shortOiUsd ? longOiUsd - shortOiUsd : shortOiUsd - longOiUsd;
        uint256 payRate = (fundingFactorPerSecond * imbalance) / total;

        if (longOiUsd == shortOiUsd) return (0, 0);

        if (longOiUsd > shortOiUsd) {
            payRateLongs = int256(payRate);
            payRateShorts = -int256((payRate * longOiUsd) / shortOiUsd);
        } else {
            payRateShorts = int256(payRate);
            payRateLongs = -int256((payRate * shortOiUsd) / longOiUsd);
        }
    }

    function fundingPayment(uint256 sizeUsd, int256 indexNow, int256 indexEntry) internal pure returns (uint256) {
        int256 diff = indexNow >= indexEntry ? indexNow - indexEntry : indexEntry - indexNow;
        return (sizeUsd * uint256(diff)) / PRICE_SCALE;
    }

    function borrowFee(uint256 sizeUsd, uint256 ratePerSecond, uint256 dt) internal pure returns (uint256) {
        return (sizeUsd * ratePerSecond * dt) / PRICE_SCALE;
    }

    function priceImpactFee(uint256 sizeUsd, uint256 impactBps) internal pure returns (uint256) {
        return (sizeUsd * impactBps) / BPS_DENOM;
    }

    /// |long-short|/total * impactFactorBps, capped at 500 bps.
    function impactBpsFromSkew(uint256 longOi, uint256 shortOi, uint256 impactFactorBps)
        internal
        pure
        returns (uint256)
    {
        uint256 total = longOi + shortOi;
        if (total == 0 || impactFactorBps == 0) return 0;
        uint256 imb = longOi > shortOi ? longOi - shortOi : shortOi - longOi;
        uint256 bps = (imb * impactFactorBps) / total;
        return bps > 500 ? 500 : bps;
    }

    function netEquity(uint256 equity, uint256 fees) internal pure returns (uint256) {
        return equity > fees ? equity - fees : 0;
    }

    /// @notice Protocol take on positive PnL. Default 10 bps = 0.1%.
    function profitFee(uint256 profitUsd, uint32 feeBps) internal pure returns (uint256) {
        if (profitUsd == 0 || feeBps == 0) return 0;
        return (profitUsd * feeBps) / BPS_DENOM;
    }
}
