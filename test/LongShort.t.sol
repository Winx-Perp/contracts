// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PerpEngine} from "../src/PerpEngine.sol";
import {Vault} from "../src/Vault.sol";
import {MockPriceOracle} from "../src/oracle/MockPriceOracle.sol";
import {MockVerifier} from "../src/verifiers/MockVerifier.sol";
import {TriggerOrderModule} from "../src/orders/TriggerOrderModule.sol";
import {OrderKind} from "../src/orders/OrderTypes.sol";
import {PerpMath} from "../src/lib/PerpMath.sol";
import {MockERC20} from "./MockERC20.sol";
import {
    ClosePublicInputs,
    EngineVerifiers,
    Groth16Proof,
    OpenPublicInputs,
    ShieldPublicInputs
} from "../src/lib/Types.sol";

contract LongShortTest is Test {
    uint32 internal constant MARKET = 1;
    uint32 internal constant COL = 1;
    bytes32 internal constant FEED = keccak256("BTCUSD");
    uint256 internal constant ENTRY = 60_000e8;

    MockERC20 internal token;
    MockPriceOracle internal oracle;
    MockVerifier internal verifier;
    Vault internal vault;
    PerpEngine internal engine;
    TriggerOrderModule internal limitMod;
    TriggerOrderModule internal stopMod;
    TriggerOrderModule internal takeMod;

    address internal trader = address(0xA11CE);

    function setUp() public {
        token = new MockERC20();
        oracle = new MockPriceOracle();
        verifier = new MockVerifier();
        vault = new Vault(address(this), address(token), address(verifier), address(verifier), address(0));
        engine = new PerpEngine(
            address(this),
            address(vault),
            address(oracle),
            EngineVerifiers({
                open: address(verifier),
                close: address(verifier),
                liquidate: address(verifier),
                increase: address(verifier),
                decrease: address(verifier),
                health: address(verifier)
            })
        );
        vault.setEngine(address(engine));
        limitMod = new TriggerOrderModule(address(engine), OrderKind.Limit);
        stopMod = new TriggerOrderModule(address(engine), OrderKind.StopMarket);
        takeMod = new TriggerOrderModule(address(engine), OrderKind.TakeMarket);
        engine.setOrderModule(OrderKind.Limit, address(limitMod));
        engine.setOrderModule(OrderKind.StopMarket, address(stopMod));
        engine.setOrderModule(OrderKind.TakeMarket, address(takeMod));
        engine.listMarket(MARKET, FEED, 50, 100);
        oracle.setPrice(FEED, ENTRY, block.timestamp);
        token.mint(trader, 100_000e6);
        vm.prank(trader);
        token.approve(address(vault), type(uint256).max);
    }

    function test_longLimitOpensWhenPriceAtOrBelowTrigger() public {
        bytes32 pos = keccak256("long-limit");
        uint256 id = _placeOpen(limitMod, true, pos, keccak256("n-ll"), ENTRY);
        engine.executeOrder(OrderKind.Limit, _empty(), abi.encode(id));
        assertTrue(engine.positions(pos));
    }

    function test_longLimitRejectsWhenPriceAboveTrigger() public {
        uint256 id = _placeOpen(limitMod, true, keccak256("long-miss"), keccak256("n-lm"), ENTRY - 1);
        vm.expectRevert(TriggerOrderModule.TriggerNotMet.selector);
        engine.executeOrder(OrderKind.Limit, _empty(), abi.encode(id));
    }

    function test_shortLimitOpensWhenPriceAtOrAboveTrigger() public {
        bytes32 pos = keccak256("short-limit");
        uint256 id = _placeOpen(limitMod, false, pos, keccak256("n-sl"), ENTRY);
        engine.executeOrder(OrderKind.Limit, _empty(), abi.encode(id));
        assertTrue(engine.positions(pos));
    }

    function test_shortLimitRejectsWhenPriceBelowTrigger() public {
        uint256 id = _placeOpen(limitMod, false, keccak256("short-miss"), keccak256("n-sm"), ENTRY + 1);
        vm.expectRevert(TriggerOrderModule.TriggerNotMet.selector);
        engine.executeOrder(OrderKind.Limit, _empty(), abi.encode(id));
    }

    function test_longStopOpensOnRally() public {
        oracle.setPrice(FEED, 61_000e8, block.timestamp);
        bytes32 pos = keccak256("long-stop");
        uint256 id = _placeOpen(stopMod, true, pos, keccak256("n-ls"), 61_000e8);
        engine.executeOrder(OrderKind.StopMarket, _empty(), abi.encode(id));
        assertTrue(engine.positions(pos));
    }

    function test_shortStopOpensOnDump() public {
        oracle.setPrice(FEED, 59_000e8, block.timestamp);
        bytes32 pos = keccak256("short-stop");
        uint256 id = _placeOpen(stopMod, false, pos, keccak256("n-ss"), 59_000e8);
        engine.executeOrder(OrderKind.StopMarket, _empty(), abi.encode(id));
        assertTrue(engine.positions(pos));
    }

    function test_longTakeProfitClosesOnRally() public {
        bytes32 pos = keccak256("long-tp");
        engine.executeOrder(
            OrderKind.Limit, _empty(), abi.encode(_placeOpen(limitMod, true, pos, keccak256("n-ltp"), ENTRY))
        );
        oracle.setPrice(FEED, 66_000e8, block.timestamp);
        uint256 id = takeMod.place(false, true, MARKET, 66_000e8, 0, abi.encode(_close(pos, keccak256("pn-ltp"), 66_000e8)));
        engine.executeOrder(OrderKind.TakeMarket, _empty(), abi.encode(id));
        assertFalse(engine.positions(pos));
    }

    function test_shortTakeProfitClosesOnDump() public {
        bytes32 pos = keccak256("short-tp");
        engine.executeOrder(
            OrderKind.Limit, _empty(), abi.encode(_placeOpen(limitMod, false, pos, keccak256("n-stp"), ENTRY))
        );
        oracle.setPrice(FEED, 54_000e8, block.timestamp);
        uint256 id = takeMod.place(false, false, MARKET, 54_000e8, 0, abi.encode(_close(pos, keccak256("pn-stp"), 54_000e8)));
        engine.executeOrder(OrderKind.TakeMarket, _empty(), abi.encode(id));
        assertFalse(engine.positions(pos));
    }

    function test_longAndShortMarketRoundTrip() public {
        bytes32 longPos = keccak256("mkt-long");
        bytes32 shortPos = keccak256("mkt-short");
        engine.executeOrder(
            OrderKind.Limit, _empty(), abi.encode(_placeOpen(limitMod, true, longPos, keccak256("n-ml"), ENTRY))
        );
        engine.executeOrder(
            OrderKind.Limit, _empty(), abi.encode(_placeOpen(limitMod, false, shortPos, keccak256("n-ms"), ENTRY))
        );
        oracle.setPrice(FEED, 66_000e8, block.timestamp);
        engine.close(_empty(), _close(longPos, keccak256("pn-ml"), 66_000e8));
        engine.close(_empty(), _close(shortPos, keccak256("pn-ms"), 66_000e8));
        assertFalse(engine.positions(longPos));
        assertFalse(engine.positions(shortPos));
    }

    function test_pnlLongProfitShortLossOnRally() public pure {
        uint256 size = 10_000e6;
        int256 longPnl = PerpMath.positionPnlUsd(size, true, ENTRY, 66_000e8);
        int256 shortPnl = PerpMath.positionPnlUsd(size, false, ENTRY, 66_000e8);
        assertEq(longPnl, int256(1_000e6));
        assertEq(shortPnl, -int256(1_000e6));
        assertEq(longPnl, -shortPnl);
    }

    function test_pnlShortProfitLongLossOnDump() public pure {
        uint256 size = 10_000e6;
        int256 longPnl = PerpMath.positionPnlUsd(size, true, ENTRY, 54_000e8);
        int256 shortPnl = PerpMath.positionPnlUsd(size, false, ENTRY, 54_000e8);
        assertEq(longPnl, -int256(1_000e6));
        assertEq(shortPnl, int256(1_000e6));
    }

    function test_fundingLongsPayWhenLongOiDominates() public pure {
        (int256 payLong, int256 payShort) =
            PerpMath.fundingRatePerSecond(150_000e6, 50_000e6, uint256(1e8) / 50_000);
        assertGt(payLong, 0);
        assertLt(payShort, 0);
    }

    function test_fundingShortsPayWhenShortOiDominates() public pure {
        (int256 payLong, int256 payShort) =
            PerpMath.fundingRatePerSecond(50_000e6, 150_000e6, uint256(1e8) / 50_000);
        assertLt(payLong, 0);
        assertGt(payShort, 0);
    }

    function _placeOpen(TriggerOrderModule mod, bool isLong, bytes32 pos, bytes32 note, uint256 mark)
        internal
        returns (uint256 id)
    {
        vm.prank(trader);
        vault.shield(_empty(), ShieldPublicInputs({noteCommitment: note, collateralId: COL, amount: 1_000e6}));
        OpenPublicInputs memory payload = OpenPublicInputs({
            merkleRoot: vault.currentRoot(),
            noteNullifier: keccak256(abi.encode(note, "null")),
            positionCommitment: pos,
            changeNoteCommitment: bytes32(0),
            markPrice: mark,
                openedAt: block.timestamp,
            marketId: MARKET,
            collateralId: COL
        });
        id = mod.place(true, isLong, MARKET, mark, 0, abi.encode(payload));
    }

    function _close(bytes32 pos, bytes32 posNull, uint256 exit)
        internal
        pure
        returns (ClosePublicInputs memory)
    {
        return ClosePublicInputs({
            positionCommitment: pos,
            positionNullifier: posNull,
            payoutNoteCommitment: keccak256(abi.encode(pos, "payout")),
            exitPrice: exit,
            protocolFee: 0,
            marketId: MARKET,
            collateralId: COL
        });
    }

    function _empty() internal pure returns (Groth16Proof memory p) {}
}
