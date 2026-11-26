// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {USDW} from "../src/token/USDW.sol";
import {PnlPool} from "../src/PnlPool.sol";
import {Vault} from "../src/Vault.sol";
import {PerpEngine} from "../src/PerpEngine.sol";
import {MockVerifier} from "../src/verifiers/MockVerifier.sol";
import {MockPriceOracle} from "../src/oracle/MockPriceOracle.sol";
import {Auth} from "../src/lib/Auth.sol";
import {PerpMath} from "../src/lib/PerpMath.sol";
import {
    ClosePublicInputs,
    EngineVerifiers,
    Groth16Proof,
    LiquidatePublicInputs,
    OpenPublicInputs,
    ShieldPublicInputs
} from "../src/lib/Types.sol";

contract PnlPoolTest is Test {
    address internal admin = address(0xA0);
    address internal trader = address(0xB0);
    USDW internal usdw;
    PnlPool internal pool;
    Vault internal vault;
    PerpEngine internal engine;
    MockPriceOracle internal oracle;
    Groth16Proof internal proof;

    uint32 internal constant MARKET = 1;
    bytes32 internal constant FEED = keccak256("BTC");
    uint256 internal constant PRICE = 60_000e8;

    function setUp() public {
        usdw = new USDW(admin);
        pool = new PnlPool(admin, address(usdw));
        MockVerifier v = new MockVerifier();
        oracle = new MockPriceOracle();
        vault = new Vault(admin, address(usdw), address(v), address(v), address(0));
        engine = new PerpEngine(
            admin,
            address(vault),
            address(oracle),
            EngineVerifiers({
                open: address(v),
                close: address(v),
                liquidate: address(v),
                increase: address(v),
                decrease: address(v),
                health: address(v)
            })
        );
        vm.startPrank(admin);
        vault.setEngine(address(engine));
        engine.setPnlPool(address(pool));
        pool.setEngine(address(engine));
        engine.listMarket(MARKET, FEED, 40, 100);
        oracle.setPrice(FEED, PRICE, block.timestamp);
        usdw.approve(address(pool), type(uint256).max);
        usdw.approve(address(vault), type(uint256).max);
        usdw.transfer(trader, 10_000e6);
        pool.deposit(1_000_000e6);
        vm.stopPrank();
        vm.prank(trader);
        usdw.approve(address(vault), type(uint256).max);
    }

    function test_adminDepositWithdrawHouse() public {
        assertEq(pool.houseBalance(), 1_000_000e6);
        vm.prank(admin);
        pool.withdraw(admin, 1_000e6);
        assertEq(pool.houseBalance(), 999_000e6);
    }

    function test_nonAdminCannotDepositOrWithdraw() public {
        vm.prank(admin);
        usdw.transfer(trader, 1e6);
        vm.startPrank(trader);
        usdw.approve(address(pool), 1e6);
        vm.expectRevert(Auth.NotOwner.selector);
        pool.deposit(1e6);
        vm.expectRevert(Auth.NotOwner.selector);
        pool.withdraw(trader, 1e6);
        vm.stopPrank();
    }

    function test_coverTopsUpVault() public {
        vm.prank(admin);
        pool.cover(address(vault), 400e6);
        assertEq(pool.houseBalance(), 1_000_000e6 - 400e6);
        assertEq(usdw.balanceOf(address(vault)), 400e6);
    }

    function test_profitFeeZeroPointOnePercent() public pure {
        // $275.11 profit → 0.1% = ~$0.275
        assertEq(PerpMath.profitFee(275_109_170, 10), 275_109);
    }

    function test_closePaysProfitFeeToPool() public {
        vm.prank(trader);
        vault.shield(proof, ShieldPublicInputs({noteCommitment: keccak256("n"), collateralId: 1, amount: 1_000e6}));
        engine.open(
            proof,
            OpenPublicInputs({
                merkleRoot: vault.currentRoot(),
                noteNullifier: keccak256("nn"),
                positionCommitment: keccak256("p"),
                changeNoteCommitment: bytes32(0),
                markPrice: PRICE,
                openedAt: block.timestamp,
                marketId: MARKET,
                collateralId: 1
            })
        );
        // Mock verifier: claim $1 profit fee (0.1% of $1000).
        uint256 fee = 1e6;
        oracle.setPrice(FEED, 66_000e8, block.timestamp);
        engine.close(
            proof,
            ClosePublicInputs({
                positionCommitment: keccak256("p"),
                positionNullifier: keccak256("pn"),
                payoutNoteCommitment: keccak256("pay"),
                exitPrice: 66_000e8,
                protocolFee: fee,
                marketId: MARKET,
                collateralId: 1
            })
        );
        assertEq(pool.feesAccrued(), fee);
        assertEq(usdw.balanceOf(address(pool)), 1_000_000e6 + fee);

        vm.prank(admin);
        pool.withdrawFees(admin, fee);
        assertEq(pool.feesAccrued(), 0);
    }

    function test_liquidateSeizesMarginToPool() public {
        vm.prank(trader);
        vault.shield(proof, ShieldPublicInputs({noteCommitment: keccak256("nl"), collateralId: 1, amount: 500e6}));
        engine.open(
            proof,
            OpenPublicInputs({
                merkleRoot: vault.currentRoot(),
                noteNullifier: keccak256("nnl"),
                positionCommitment: keccak256("pl"),
                changeNoteCommitment: bytes32(0),
                markPrice: PRICE,
                openedAt: block.timestamp,
                marketId: MARKET,
                collateralId: 1
            })
        );
        uint256 seized = 500e6;
        engine.liquidate(
            proof,
            LiquidatePublicInputs({
                positionCommitment: keccak256("pl"),
                positionNullifier: keccak256("pnl"),
                leftoverNoteCommitment: bytes32(0),
                exitPrice: PRICE,
                seizedAmount: seized,
                marketId: MARKET,
                collateralId: 1,
                closedAt: block.timestamp
            })
        );
        assertEq(pool.seizedAccrued(), seized);
        uint256 before = usdw.balanceOf(admin);
        vm.prank(admin);
        pool.withdrawSeized(admin, seized);
        assertEq(pool.seizedAccrued(), 0);
        assertEq(usdw.balanceOf(admin), before + seized);
    }
}
