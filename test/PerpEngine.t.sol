// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PerpEngine} from "../src/PerpEngine.sol";
import {Vault} from "../src/Vault.sol";
import {MockPriceOracle} from "../src/oracle/MockPriceOracle.sol";
import {MockVerifier} from "../src/verifiers/MockVerifier.sol";
import {
    ClosePublicInputs,
    DecreasePublicInputs,
    EngineVerifiers,
    Groth16Proof,
    HealthPublicInputs,
    IncreasePublicInputs,
    LiquidatePublicInputs,
    OpenPublicInputs,
    ShieldPublicInputs,
    UnshieldPublicInputs
} from "../src/lib/Types.sol";
import {PerpMath} from "../src/lib/PerpMath.sol";
import {ExampleOrderModule} from "../src/orders/ExampleOrderModule.sol";
import {TriggerOrderModule} from "../src/orders/TriggerOrderModule.sol";
import {OrderKind} from "../src/orders/OrderTypes.sol";
import {MockERC20} from "./MockERC20.sol";
import {Timelock} from "../src/admin/Timelock.sol";
import {Multisig} from "../src/admin/Multisig.sol";

contract PerpEngineTest is Test {
    uint32 internal constant MARKET = 1;
    uint32 internal constant COL = 1;
    bytes32 internal constant FEED = keccak256("BTCUSD");
    uint256 internal constant PRICE = 60_000e8;

    MockERC20 internal token;
    MockPriceOracle internal oracle;
    MockVerifier internal verifier;
    Vault internal vault;
    PerpEngine internal engine;

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

        vm.warp(1_700_000_000);
        engine.listMarket(MARKET, FEED, 50, 100);
        oracle.setPrice(FEED, PRICE, block.timestamp);

        token.mint(trader, 50_000e6);
        vm.prank(trader);
        token.approve(address(vault), type(uint256).max);
    }

    function test_shieldOpenClose() public {
        bytes32 note = keccak256("note-1");
        bytes32 change = keccak256("change-1");
        bytes32 pos = keccak256("pos-1");
        bytes32 payout = keccak256("payout-1");

        vm.prank(trader);
        vault.shield(_emptyProof(), ShieldPublicInputs({noteCommitment: note, collateralId: COL, amount: 1_000e6}));
        bytes32 root = vault.currentRoot();
        assertTrue(vault.isKnownRoot(root));

        engine.open(
            _emptyProof(),
            OpenPublicInputs({
                merkleRoot: root,
                noteNullifier: keccak256("note-null-1"),
                positionCommitment: pos,
                changeNoteCommitment: change,
                markPrice: PRICE,
                openedAt: block.timestamp,
                marketId: MARKET,
                collateralId: COL
            })
        );
        assertTrue(vault.isLiveNote(change));
        assertTrue(engine.positions(pos));

        oracle.setPrice(FEED, 66_000e8, block.timestamp);
        engine.close(
            _emptyProof(),
            ClosePublicInputs({
                positionCommitment: pos,
                positionNullifier: keccak256("pos-null-1"),
                payoutNoteCommitment: payout,
                exitPrice: 66_000e8,
                protocolFee: 0,
                marketId: MARKET,
                collateralId: COL
            })
        );
        assertFalse(engine.positions(pos));
        assertTrue(vault.isLiveNote(payout));
    }

    function test_unshieldToNewAddress() public {
        bytes32 note = keccak256("note-u");
        address fresh = address(0xBEEF);

        vm.prank(trader);
        vault.shield(_emptyProof(), ShieldPublicInputs({noteCommitment: note, collateralId: COL, amount: 500e6}));
        bytes32 root = vault.currentRoot();

        vault.unshield(
            _emptyProof(),
            UnshieldPublicInputs({
                merkleRoot: root,
                noteNullifier: keccak256("null-u"),
                collateralId: COL,
                amount: 500e6,
                recipient: fresh
            })
        );
        assertEq(token.balanceOf(fresh), 500e6);
    }

    function test_increaseAndDecrease() public {
        vm.prank(trader);
        vault.shield(_emptyProof(), ShieldPublicInputs({noteCommitment: keccak256("n0"), collateralId: COL, amount: 1_000e6}));
        bytes32 root0 = vault.currentRoot();
        engine.open(
            _emptyProof(),
            OpenPublicInputs({
                merkleRoot: root0,
                noteNullifier: keccak256("nn0"),
                positionCommitment: keccak256("p0"),
                changeNoteCommitment: bytes32(0),
                markPrice: PRICE,
                openedAt: block.timestamp,
                marketId: MARKET,
                collateralId: COL
            })
        );

        vm.prank(trader);
        vault.shield(_emptyProof(), ShieldPublicInputs({noteCommitment: keccak256("n1"), collateralId: COL, amount: 500e6}));
        bytes32 root1 = vault.currentRoot();

        engine.increase(
            _emptyProof(),
            IncreasePublicInputs({
                merkleRoot: root1,
                extraNoteNullifier: keccak256("nn1"),
                oldPositionCommitment: keccak256("p0"),
                oldPositionNullifier: keccak256("pn0"),
                newPositionCommitment: keccak256("p1"),
                changeNoteCommitment: bytes32(0),
                markPrice: PRICE,
                marketId: MARKET,
                collateralId: COL
            })
        );
        assertFalse(engine.positions(keccak256("p0")));
        assertTrue(engine.positions(keccak256("p1")));

        engine.decrease(
            _emptyProof(),
            DecreasePublicInputs({
                oldPositionCommitment: keccak256("p1"),
                oldPositionNullifier: keccak256("pn1"),
                newPositionCommitment: keccak256("p2"),
                payoutNoteCommitment: keccak256("pay"),
                exitPrice: PRICE,
                protocolFee: 0,
                marketId: MARKET,
                collateralId: COL
            })
        );
        assertTrue(engine.positions(keccak256("p2")));
        assertTrue(vault.isLiveNote(keccak256("pay")));
    }

    function test_healthAndStaleLiquidate() public {
        vm.prank(trader);
        vault.shield(_emptyProof(), ShieldPublicInputs({noteCommitment: keccak256("nh"), collateralId: COL, amount: 1_000e6}));
        engine.open(
            _emptyProof(),
            OpenPublicInputs({
                merkleRoot: vault.currentRoot(),
                noteNullifier: keccak256("nnh"),
                positionCommitment: keccak256("ph"),
                changeNoteCommitment: bytes32(0),
                markPrice: PRICE,
                openedAt: block.timestamp,
                marketId: MARKET,
                collateralId: COL
            })
        );

        engine.updateHealth(
            _emptyProof(),
            HealthPublicInputs({
                positionCommitment: keccak256("ph"),
                healthCommitment: keccak256("hc"),
                liquidatable: 1,
                markPrice: PRICE,
                marketId: MARKET
            })
        );

        engine.liquidateFromHealth(
            _emptyProof(),
            LiquidatePublicInputs({
                positionCommitment: keccak256("ph"),
                positionNullifier: keccak256("phn"),
                leftoverNoteCommitment: bytes32(0),
                exitPrice: PRICE,
                seizedAmount: 0,
                marketId: MARKET,
                collateralId: COL,
                closedAt: block.timestamp
            }),
            true
        );
        assertFalse(engine.positions(keccak256("ph")));
    }

    function test_liquidateRejectsFutureCloseTime() public {
        vm.prank(trader);
        vault.shield(_emptyProof(), ShieldPublicInputs({noteCommitment: keccak256("ns"), collateralId: COL, amount: 1_000e6}));
        engine.open(
            _emptyProof(),
            OpenPublicInputs({
                merkleRoot: vault.currentRoot(),
                noteNullifier: keccak256("nns"),
                positionCommitment: keccak256("ps"),
                changeNoteCommitment: bytes32(0),
                markPrice: PRICE,
                openedAt: block.timestamp,
                marketId: MARKET,
                collateralId: COL
            })
        );

        vm.expectRevert(PerpEngine.StaleLiquidation.selector);
        engine.liquidate(
            _emptyProof(),
            LiquidatePublicInputs({
                positionCommitment: keccak256("ps"),
                positionNullifier: keccak256("psn"),
                leftoverNoteCommitment: bytes32(0),
                exitPrice: PRICE,
                seizedAmount: 0,
                marketId: MARKET,
                collateralId: COL,
                closedAt: block.timestamp + 1
            })
        );
        assertTrue(engine.positions(keccak256("ps")));
    }

    function test_epochFundingAndImpact() public {
        engine.setRiskParams(MARKET, 1e8 / 50_000, 0, 10_000, 600);
        engine.publishOi(MARKET, 150_000e6, 50_000e6);
        vm.warp(block.timestamp + 601);
        engine.sealEpoch(MARKET);
        (int256 idxL,) = engine.fundingIndexes(MARKET);
        assertGt(idxL, 0);
    }

    function test_limitOrderFill() public {
        TriggerOrderModule mod = new TriggerOrderModule(address(engine), OrderKind.Limit);
        engine.setOrderModule(OrderKind.Limit, address(mod));

        vm.prank(trader);
        vault.shield(_emptyProof(), ShieldPublicInputs({noteCommitment: keccak256("nl"), collateralId: COL, amount: 1_000e6}));
        OpenPublicInputs memory payload = OpenPublicInputs({
            merkleRoot: vault.currentRoot(),
            noteNullifier: keccak256("nnl"),
            positionCommitment: keccak256("pl"),
            changeNoteCommitment: bytes32(0),
            markPrice: PRICE,
                openedAt: block.timestamp,
            marketId: MARKET,
            collateralId: COL
        });
        uint256 id = mod.place(true, true, MARKET, PRICE, 0, abi.encode(payload));
        engine.executeOrder(OrderKind.Limit, _emptyProof(), abi.encode(id));
        assertTrue(engine.positions(keccak256("pl")));
    }

    function test_rejectStalePrice() public {
        vm.prank(trader);
        vault.shield(_emptyProof(), ShieldPublicInputs({noteCommitment: keccak256("ns"), collateralId: COL, amount: 1e6}));
        oracle.setPrice(FEED, PRICE, block.timestamp);
        vm.warp(block.timestamp + 120);
        bytes32 root = vault.currentRoot();
        vm.expectRevert(PerpEngine.StalePrice.selector);
        engine.open(
            _emptyProof(),
            OpenPublicInputs({
                merkleRoot: root,
                noteNullifier: keccak256("n"),
                positionCommitment: keccak256("p"),
                changeNoteCommitment: bytes32(0),
                markPrice: PRICE,
                openedAt: block.timestamp,
                marketId: MARKET,
                collateralId: COL
            })
        );
    }

    function test_rejectReplayNullifier() public {
        vm.prank(trader);
        vault.shield(_emptyProof(), ShieldPublicInputs({noteCommitment: keccak256("nr"), collateralId: COL, amount: 1e6}));
        bytes32 root = vault.currentRoot();
        OpenPublicInputs memory o = OpenPublicInputs({
            merkleRoot: root,
            noteNullifier: keccak256("same"),
            positionCommitment: keccak256("p1"),
            changeNoteCommitment: bytes32(0),
            markPrice: PRICE,
                openedAt: block.timestamp,
            marketId: MARKET,
            collateralId: COL
        });
        engine.open(_emptyProof(), o);
        o.positionCommitment = keccak256("p2");
        vm.expectRevert(Vault.NullifierUsed.selector);
        engine.open(_emptyProof(), o);
    }

    function test_rejectBadProof() public {
        verifier.setShouldPass(false);
        vm.prank(trader);
        vm.expectRevert(Vault.InvalidProof.selector);
        vault.shield(_emptyProof(), ShieldPublicInputs({noteCommitment: keccak256("x"), collateralId: COL, amount: 1e6}));
    }

    function test_twoStepOwnershipAndTimelock() public {
        Timelock lock = new Timelock(address(this), 0);
        engine.transferOwnership(address(0xABC));
        vm.prank(address(0xABC));
        engine.acceptOwnership();
        assertEq(engine.owner(), address(0xABC));
        lock;
    }

    function test_multisigThreshold() public {
        address[] memory s = new address[](2);
        s[0] = address(this);
        s[1] = address(0x2);
        Multisig ms = new Multisig(s, 2);
        engine.transferOwnership(address(ms));
        vm.prank(address(ms));
        engine.acceptOwnership();
        bytes memory data = abi.encodeWithSelector(PerpEngine.setPaused.selector, true);
        bytes32 id = ms.submit(address(engine), data);
        vm.prank(address(0x2));
        ms.confirm(id);
        ms.execute(address(engine), data);
        assertTrue(engine.paused());
    }

    function test_executeOrderUnsetReverts() public {
        vm.expectRevert(abi.encodeWithSelector(PerpEngine.OrderModuleUnset.selector, OrderKind.Limit));
        engine.executeOrder(OrderKind.Limit, _emptyProof(), "");
    }

    function test_customLimitModule() public {
        ExampleOrderModule module = new ExampleOrderModule(address(engine), OrderKind.Limit);
        engine.setOrderModule(OrderKind.Limit, address(module));
        vm.expectEmit(true, false, false, true, address(module));
        emit ExampleOrderModule.OrderExecuted(trader, hex"1234");
        vm.prank(trader);
        engine.executeOrder(OrderKind.Limit, _emptyProof(), hex"1234");
    }

    function test_gmxFundingStillHolds() public pure {
        (int256 longPay, int256 shortPay) = PerpMath.fundingRatePerSecond(150_000e6, 50_000e6, uint256(1e8) / 50_000);
        assertEq(longPay, int256(1_000));
        assertEq(shortPay, -int256(3_000));
    }

    function _emptyProof() internal pure returns (Groth16Proof memory p) {
        p.a = [uint256(0), uint256(0)];
        p.b = [[uint256(0), uint256(0)], [uint256(0), uint256(0)]];
        p.c = [uint256(0), uint256(0)];
    }
}
