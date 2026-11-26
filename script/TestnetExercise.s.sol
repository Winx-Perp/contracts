// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {USDW} from "../src/token/USDW.sol";
import {EthUsdwSwap} from "../src/token/EthUsdwSwap.sol";
import {Vault} from "../src/Vault.sol";
import {PerpEngine} from "../src/PerpEngine.sol";
import {MockPriceOracle} from "../src/oracle/MockPriceOracle.sol";
import {TriggerOrderModule} from "../src/orders/TriggerOrderModule.sol";
import {OrderKind} from "../src/orders/OrderTypes.sol";
import {Timelock} from "../src/admin/Timelock.sol";
import {Multisig} from "../src/admin/Multisig.sol";
import {MockERC20} from "../test/MockERC20.sol";
import {
    ClosePublicInputs,
    DecreasePublicInputs,
    Groth16Proof,
    HealthPublicInputs,
    IncreasePublicInputs,
    LiquidatePublicInputs,
    OpenPublicInputs,
    ShieldPublicInputs,
    UnshieldPublicInputs
} from "../src/lib/Types.sol";

/// Remaining testnet flows on the already-deployed stack, then Timelock + Multisig.
contract TestnetExercise is Script {
    uint32 internal constant MARKET_BTC = 1;
    uint32 internal constant MARKET_ETH = 2;

    bytes32 internal constant POS_BTC = keccak256("winx-smoke-pos");
    bytes32 internal constant POS_ETH = keccak256("winx2-eth-pos");
    bytes32 internal constant POS_ETH2 = keccak256("winx2-eth-pos-2");
    bytes32 internal constant POS_ETH3 = keccak256("winx2-eth-pos-3");
    bytes32 internal constant POS_LIQ = keccak256("winx2-liq-pos");

    USDW internal usdw;
    EthUsdwSwap internal swap;
    Vault internal vault;
    PerpEngine internal engine;
    MockPriceOracle internal oracle;
    TriggerOrderModule internal limitMod;
    Timelock internal lock;
    Multisig internal ms;
    MockERC20 internal extra;

    uint256 internal btcPx;
    uint256 internal ethPx;
    bytes32 internal btcId;
    bytes32 internal ethId;
    address internal admin;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        admin = vm.envAddress("ADMIN");
        usdw = USDW(vm.envAddress("USDW"));
        swap = EthUsdwSwap(payable(vm.envAddress("ETH_USDW_SWAP")));
        vault = Vault(vm.envAddress("VAULT"));
        engine = PerpEngine(vm.envAddress("ENGINE"));
        oracle = MockPriceOracle(vm.envAddress("ORACLE"));
        btcPx = vm.envOr("BTC_MARK_1E8", uint256(64_808e8));
        ethPx = vm.envOr("ETH_MARK_1E8", uint256(1_832e8));
        btcId = bytes32(uint256(uint160(vm.envAddress("CHAINLINK_BTC_USD"))));
        ethId = bytes32(uint256(uint160(vm.envAddress("CHAINLINK_ETH_USD"))));
        limitMod = TriggerOrderModule(address(engine.orderModules(OrderKind.Limit)));

        vm.startBroadcast(pk);
        _refresh();
        _closeBtcUnshield();
        _swapShieldLimitEth();
        _increaseDecrease();
        _healthLiquidate();
        _funding();
        _extraCollateral();
        _deployAdmin();
        vm.stopBroadcast();

        console2.log("TIMELOCK", address(lock));
        console2.log("MULTISIG", address(ms));
        console2.log("EXTRA_COL", address(extra));
        console2.log("btc_closed", !engine.positions(POS_BTC));
        console2.log("eth_open", engine.positions(POS_ETH3) || engine.positions(POS_ETH2) || engine.positions(POS_ETH));
        console2.log("liq_gone", !engine.positions(POS_LIQ));
        console2.log("usdw_admin", usdw.balanceOf(admin));
        console2.log("usdw_vault", usdw.balanceOf(address(vault)));
    }

    function _proof() internal pure returns (Groth16Proof memory p) {}

    function _refresh() internal {
        oracle.setPrice(btcId, btcPx, block.timestamp);
        oracle.setPrice(ethId, ethPx, block.timestamp);
    }

    function _closeBtcUnshield() internal {
        engine.close(
            _proof(),
            ClosePublicInputs({
                positionCommitment: POS_BTC,
                positionNullifier: keccak256("winx2-btc-pos-null"),
                payoutNoteCommitment: keccak256("winx2-payout"),
                exitPrice: btcPx,
                protocolFee: 0,
                marketId: MARKET_BTC,
                collateralId: 1
            })
        );
        vault.unshield(
            _proof(),
            UnshieldPublicInputs({
                merkleRoot: vault.currentRoot(),
                noteNullifier: keccak256("winx2-payout-null"),
                collateralId: 1,
                amount: 100e6,
                recipient: admin
            })
        );
    }

    function _swapShieldLimitEth() internal {
        swap.swap{value: 0.0005 ether}();
        vault.shield(
            _proof(),
            ShieldPublicInputs({noteCommitment: keccak256("winx2-eth-note"), collateralId: 1, amount: 200e6})
        );
        OpenPublicInputs memory payload = OpenPublicInputs({
            merkleRoot: vault.currentRoot(),
            noteNullifier: keccak256("winx2-eth-null"),
            positionCommitment: POS_ETH,
            changeNoteCommitment: bytes32(0),
            markPrice: ethPx,
            openedAt: block.timestamp,
            marketId: MARKET_ETH,
            collateralId: 1
        });
        uint256 id = limitMod.place(true, true, MARKET_ETH, ethPx + 1, 0, abi.encode(payload));
        engine.executeOrder(OrderKind.Limit, _proof(), abi.encode(id));
    }

    function _increaseDecrease() internal {
        vault.shield(
            _proof(),
            ShieldPublicInputs({noteCommitment: keccak256("winx2-inc-note"), collateralId: 1, amount: 50e6})
        );
        engine.increase(
            _proof(),
            IncreasePublicInputs({
                merkleRoot: vault.currentRoot(),
                extraNoteNullifier: keccak256("winx2-inc-null"),
                oldPositionCommitment: POS_ETH,
                oldPositionNullifier: keccak256("winx2-eth-pos-null"),
                newPositionCommitment: POS_ETH2,
                changeNoteCommitment: bytes32(0),
                markPrice: ethPx,
                marketId: MARKET_ETH,
                collateralId: 1
            })
        );
        engine.decrease(
            _proof(),
            DecreasePublicInputs({
                oldPositionCommitment: POS_ETH2,
                oldPositionNullifier: keccak256("winx2-eth-pos-null-2"),
                newPositionCommitment: POS_ETH3,
                payoutNoteCommitment: keccak256("winx2-dec-payout"),
                exitPrice: ethPx,
                protocolFee: 0,
                marketId: MARKET_ETH,
                collateralId: 1
            })
        );
    }

    function _healthLiquidate() internal {
        vault.shield(
            _proof(),
            ShieldPublicInputs({noteCommitment: keccak256("winx2-liq-note"), collateralId: 1, amount: 50e6})
        );
        engine.open(
            _proof(),
            OpenPublicInputs({
                merkleRoot: vault.currentRoot(),
                noteNullifier: keccak256("winx2-liq-null"),
                positionCommitment: POS_LIQ,
                changeNoteCommitment: bytes32(0),
                markPrice: btcPx,
            openedAt: block.timestamp,
                marketId: MARKET_BTC,
                collateralId: 1
            })
        );
        engine.updateHealth(
            _proof(),
            HealthPublicInputs({
                positionCommitment: POS_LIQ,
                healthCommitment: keccak256("winx2-health"),
                liquidatable: 1,
                markPrice: btcPx,
                marketId: MARKET_BTC
            })
        );
        engine.liquidateFromHealth(
            _proof(),
            LiquidatePublicInputs({
                positionCommitment: POS_LIQ,
                positionNullifier: keccak256("winx2-liq-pos-null"),
                leftoverNoteCommitment: bytes32(0),
                exitPrice: btcPx,
                seizedAmount: 0,
                marketId: MARKET_BTC,
                collateralId: 1,
                closedAt: block.timestamp
            }),
            true
        );
    }

    function _funding() internal {
        engine.setRiskParams(MARKET_BTC, uint256(1e8) / 50_000, 0, 10_000, 1);
        engine.publishOi(MARKET_BTC, 150_000e6, 50_000e6);
        engine.sealEpoch(MARKET_BTC);
    }

    function _extraCollateral() internal {
        extra = new MockERC20();
        extra.mint(admin, 1_000e6);
        extra.approve(address(vault), type(uint256).max);
        vault.addCollateral(2, address(extra), 6, true);
        vault.shield(
            _proof(), ShieldPublicInputs({noteCommitment: keccak256("winx2-usdc-note"), collateralId: 2, amount: 25e6})
        );
    }

    function _deployAdmin() internal {
        lock = new Timelock(admin, 0);
        address[] memory signers = new address[](1);
        signers[0] = admin;
        ms = new Multisig(signers, 1);
    }
}
