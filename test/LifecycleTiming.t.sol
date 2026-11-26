// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {USDW} from "../src/token/USDW.sol";
import {Vault} from "../src/Vault.sol";
import {PerpEngine} from "../src/PerpEngine.sol";
import {PnlPool} from "../src/PnlPool.sol";
import {MockVerifier} from "../src/verifiers/MockVerifier.sol";
import {MockPriceOracle} from "../src/oracle/MockPriceOracle.sol";
import {KeccakHasher} from "../src/lib/Hasher.sol";
import {
    ClosePublicInputs,
    EngineVerifiers,
    Groth16Proof,
    HealthPublicInputs,
    LiquidatePublicInputs,
    OpenPublicInputs,
    ShieldPublicInputs
} from "../src/lib/Types.sol";

/// Gas / wall-clock settle timings for open → close and open → auto-liquidate.
/// Proof generation is measured in privacy_layer/test/lifecycle_timing.test.js.
contract LifecycleTimingTest is Test {
    uint32 internal constant MARKET = 1;
    uint32 internal constant COL = 1;
    bytes32 internal constant FEED = bytes32(uint256(1));
    uint256 internal constant PRICE = 64_808e8;
    uint256 internal constant EXIT_UP = 70_000e8;
    uint256 internal constant EXIT_DOWN = 50_000e8;

    USDW internal usdw;
    Vault internal vault;
    PerpEngine internal engine;
    PnlPool internal pool;
    MockPriceOracle internal oracle;
    MockVerifier internal verifier;
    address internal trader = address(0xBEEF);

    function setUp() public {
        usdw = new USDW(address(this));
        verifier = new MockVerifier();
        oracle = new MockPriceOracle();
        oracle.setPrice(FEED, PRICE, block.timestamp);

        EngineVerifiers memory v = EngineVerifiers({
            open: address(verifier),
            close: address(verifier),
            liquidate: address(verifier),
            increase: address(verifier),
            decrease: address(verifier),
            health: address(verifier)
        });

        vault = new Vault(address(this), address(usdw), address(verifier), address(verifier), address(new KeccakHasher()));
        engine = new PerpEngine(address(this), address(vault), address(oracle), v);
        pool = new PnlPool(address(this), address(usdw));
        vault.setEngine(address(engine));
        engine.setPnlPool(address(pool));
        pool.setEngine(address(engine));
        engine.setMaxPriceAge(1 hours);
        engine.setMaxOpenAge(1 hours);
        engine.listMarket(MARKET, FEED, 40, 100);

        usdw.transfer(trader, 10_000e6);
        usdw.approve(address(pool), 1_000_000e6);
        pool.deposit(1_000_000e6);
    }

    function _empty() internal pure returns (Groth16Proof memory p) {}

    function _shield(bytes32 note, uint256 amount) internal {
        vm.startPrank(trader);
        usdw.approve(address(vault), amount);
        vault.shield(_empty(), ShieldPublicInputs({noteCommitment: note, collateralId: COL, amount: amount}));
        vm.stopPrank();
    }

    function test_timing_openClose() public {
        bytes32 note = keccak256("timing-open-note");
        bytes32 pos = keccak256("timing-open-pos");
        _shield(note, 400e6);

        uint256 g0 = gasleft();
        uint256 t0 = block.timestamp; // placeholder; gas is the on-chain metric
        engine.open(
            _empty(),
            OpenPublicInputs({
                merkleRoot: vault.currentRoot(),
                noteNullifier: keccak256("timing-open-null"),
                positionCommitment: pos,
                changeNoteCommitment: bytes32(0),
                markPrice: PRICE,
                openedAt: block.timestamp,
                marketId: MARKET,
                collateralId: COL
            })
        );
        uint256 openGas = g0 - gasleft();
        assertTrue(engine.positions(pos));

        oracle.setPrice(FEED, EXIT_UP, block.timestamp);
        g0 = gasleft();
        engine.close(
            _empty(),
            ClosePublicInputs({
                positionCommitment: pos,
                positionNullifier: keccak256("timing-close-null"),
                payoutNoteCommitment: keccak256("timing-payout"),
                exitPrice: EXIT_UP,
                protocolFee: 1e6,
                marketId: MARKET,
                collateralId: COL
            })
        );
        uint256 closeGas = g0 - gasleft();
        assertFalse(engine.positions(pos));

        console2.log("settle_open_gas", openGas);
        console2.log("settle_close_gas", closeGas);
        console2.log("openedAt_ref", t0);
    }

    function test_timing_autoLiquidate() public {
        bytes32 note = keccak256("timing-liq-note");
        bytes32 pos = keccak256("timing-liq-pos");
        _shield(note, 400e6);

        engine.open(
            _empty(),
            OpenPublicInputs({
                merkleRoot: vault.currentRoot(),
                noteNullifier: keccak256("timing-liq-nn"),
                positionCommitment: pos,
                changeNoteCommitment: bytes32(0),
                markPrice: PRICE,
                openedAt: block.timestamp,
                marketId: MARKET,
                collateralId: COL
            })
        );

        oracle.setPrice(FEED, EXIT_DOWN, block.timestamp);

        uint256 g0 = gasleft();
        engine.updateHealth(
            _empty(),
            HealthPublicInputs({
                positionCommitment: pos,
                healthCommitment: keccak256("timing-hc"),
                liquidatable: 1,
                markPrice: EXIT_DOWN,
                marketId: MARKET
            })
        );
        uint256 healthGas = g0 - gasleft();

        g0 = gasleft();
        engine.liquidateFromHealth(
            _empty(),
            LiquidatePublicInputs({
                positionCommitment: pos,
                positionNullifier: keccak256("timing-liq-pn"),
                leftoverNoteCommitment: bytes32(0),
                exitPrice: EXIT_DOWN,
                seizedAmount: 400e6,
                marketId: MARKET,
                collateralId: COL,
                closedAt: block.timestamp
            }),
            true
        );
        uint256 liqGas = g0 - gasleft();
        assertFalse(engine.positions(pos));
        assertEq(pool.seizedAccrued(), 400e6);

        console2.log("settle_health_gas", healthGas);
        console2.log("settle_liquidateFromHealth_gas", liqGas);
        console2.log("auto_liq_total_gas", healthGas + liqGas);
    }

    function test_timing_ownershipNullifierAndPermitSig() public {
        // Ownership on-chain is demonstrated by submitting a nullifier that only
        // the secret holder can derive; here we measure EIP-712 permit signing (owner auth).
        uint256 pk = 0xA11CE;
        address owner = vm.addr(pk);
        usdw.transfer(owner, 100e6);

        uint256 deadline = block.timestamp + 1 hours;
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                usdw.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(usdw.PERMIT_TYPEHASH(), owner, address(this), uint256(40e6), uint256(0), deadline))
            )
        );

        uint256 g0 = gasleft();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        uint256 signGasProxy = g0 - gasleft(); // forge cheatcode cost, not secp256k1 wall time

        usdw.permit(owner, address(this), 40e6, deadline, v, r, s);
        assertEq(usdw.allowance(owner, address(this)), 40e6);
        console2.log("permit_sign_cheatcode_gas", signGasProxy);
        console2.log("sig_v", v);
    }
}
