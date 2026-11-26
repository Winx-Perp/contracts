// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PerpMath} from "../src/lib/PerpMath.sol";

/// PnL at ETH 30x / BTC 40x for the testnet price path (margin $100).
contract LeveragePnlTest is Test {
    uint256 internal constant MARGIN = 100e6;
    uint256 internal constant ETH_ENTRY = 1_832e8;
    uint256 internal constant ETH_RALLY = 2_000e8;
    uint256 internal constant ETH_DUMP = 1_700e8;
    uint256 internal constant BTC_ENTRY = 64_808e8;
    uint256 internal constant BTC_DUMP = 60_000e8;
    uint256 internal constant BTC_RALLY = 70_000e8;

    function test_eth30xLongProfitsOnRally() public pure {
        uint256 size = MARGIN * 30;
        int256 pnl = PerpMath.positionPnlUsd(size, true, ETH_ENTRY, ETH_RALLY);
        assertGt(pnl, 0);
        int256 pnl10 = PerpMath.positionPnlUsd(MARGIN * 10, true, ETH_ENTRY, ETH_RALLY);
        assertGt(pnl, pnl10 * 2);
        assertApproxEqAbs(pnl, pnl10 * 3, 10);
    }

    function test_btc40xShortProfitsOnDump() public pure {
        uint256 size = MARGIN * 40;
        int256 pnl = PerpMath.positionPnlUsd(size, false, BTC_ENTRY, BTC_DUMP);
        assertGt(pnl, 0);
        int256 pnl10 = PerpMath.positionPnlUsd(MARGIN * 10, false, BTC_ENTRY, BTC_DUMP);
        assertApproxEqAbs(pnl, pnl10 * 4, 10);
    }

    function test_eth30xShortProfitsOnDump() public pure {
        int256 pnl = PerpMath.positionPnlUsd(MARGIN * 30, false, ETH_RALLY, ETH_DUMP);
        assertGt(pnl, 0);
    }

    function test_btc40xLongProfitsOnRally() public pure {
        int256 pnl = PerpMath.positionPnlUsd(MARGIN * 40, true, BTC_DUMP, BTC_RALLY);
        assertGt(pnl, 0);
    }

    function test_wrongSideLosesTheSameAmount() public pure {
        uint256 size = MARGIN * 30;
        int256 longWin = PerpMath.positionPnlUsd(size, true, ETH_ENTRY, ETH_RALLY);
        int256 shortLose = PerpMath.positionPnlUsd(size, false, ETH_ENTRY, ETH_RALLY);
        assertEq(longWin, -shortLose);
    }

    function test_40xLiquidatesFasterThan30xOnSameMove() public pure {
        // ~2% BTC dump: 40x (2.5% cushion) is liquidatable at 1% mm; 30x is not.
        uint256 px = 63_512e8;
        uint256 size40 = MARGIN * 40;
        uint256 size30 = MARGIN * 30;
        uint256 eq40 = PerpMath.equityUsd(MARGIN, PerpMath.positionPnlUsd(size40, true, BTC_ENTRY, px));
        uint256 eq30 = PerpMath.equityUsd(MARGIN, PerpMath.positionPnlUsd(size30, true, BTC_ENTRY, px));
        assertTrue(PerpMath.isLiquidatable(eq40, size40, 100));
        assertFalse(PerpMath.isLiquidatable(eq30, size30, 100));
        assertLt(eq40, eq30);
    }
}
