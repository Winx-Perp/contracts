// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PerpMath} from "../src/lib/PerpMath.sol";

contract PerpMathTest is Test {
    uint256 internal constant PRICE = 60_000e8;

    function test_gmxPnlMatchesLinearFullClose() public pure {
        uint256 size = 10_000e6;
        uint256 exit = 66_000e8;
        int256 gmx = PerpMath.positionPnlUsd(size, true, PRICE, exit);
        int256 linear = PerpMath.linearPnl(size, true, PRICE, exit);
        assertEq(gmx, linear);
        assertEq(gmx, int256(1_000e6));
        assertEq(PerpMath.equityUsd(1_000e6, gmx), 2_000e6);
    }

    function test_shortPnl() public pure {
        int256 pnl = PerpMath.positionPnlUsd(10_000e6, false, PRICE, 54_000e8);
        assertEq(pnl, int256(1_000e6));
    }

    function test_underwaterEquityZero() public pure {
        int256 pnl = PerpMath.positionPnlUsd(10_000e6, true, PRICE, 48_000e8);
        assertEq(pnl, -int256(2_000e6));
        assertEq(PerpMath.equityUsd(1_000e6, pnl), 0);
        assertTrue(PerpMath.isLiquidatable(0, 10_000e6, 100));
    }

    function test_gmxLiquidationThreshold() public pure {
        // 1% mm, size 10_000 → min collateral for leverage = 100
        assertTrue(PerpMath.isLiquidatable(99e6, 10_000e6, 100));
        assertFalse(PerpMath.isLiquidatable(100e6, 10_000e6, 100));
    }

    function test_gmxFundingWorkedExample() public pure {
        // README: factor 1/50000, long 150k, short 50k
        // longs pay 0.001%/s, shorts receive 0.003%/s
        uint256 factor = uint256(1e8) / 50_000;
        (int256 longPay, int256 shortPay) = PerpMath.fundingRatePerSecond(150_000e6, 50_000e6, factor);
        assertEq(longPay, int256(1_000)); // 1000 / 1e8 = 0.001%
        assertEq(shortPay, -int256(3_000));
    }
}
