// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {USDW} from "../src/token/USDW.sol";
import {Vault} from "../src/Vault.sol";
import {PerpEngine} from "../src/PerpEngine.sol";
import {MockPriceOracle} from "../src/oracle/MockPriceOracle.sol";
import {TriggerOrderModule} from "../src/orders/TriggerOrderModule.sol";
import {OrderKind} from "../src/orders/OrderTypes.sol";
import {PerpMath} from "../src/lib/PerpMath.sol";
import {
    ClosePublicInputs,
    Groth16Proof,
    OpenPublicInputs,
    ShieldPublicInputs
} from "../src/lib/Types.sol";

/// Live long/short trading on the deployed testnet engine.
contract TestnetLongShort is Script {
    uint32 internal constant MARKET_BTC = 1;
    uint32 internal constant MARKET_ETH = 2;

    bytes32 internal constant LONG_ETH = keccak256("ls-long-eth");
    bytes32 internal constant SHORT_BTC = keccak256("ls-short-btc");
    bytes32 internal constant LONG_STOP = keccak256("ls-long-stop-btc");
    bytes32 internal constant SHORT_TAKE = keccak256("ls-short-take-eth");

    USDW internal usdw;
    Vault internal vault;
    PerpEngine internal engine;
    MockPriceOracle internal oracle;
    TriggerOrderModule internal limitMod;
    TriggerOrderModule internal stopMod;
    TriggerOrderModule internal takeMod;

    uint256 internal btcPx;
    uint256 internal ethPx;
    uint256 internal btcDump;
    uint256 internal ethRally;
    bytes32 internal btcId;
    bytes32 internal ethId;
    address internal admin;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        admin = vm.envAddress("ADMIN");
        usdw = USDW(vm.envAddress("USDW"));
        vault = Vault(vm.envAddress("VAULT"));
        engine = PerpEngine(vm.envAddress("ENGINE"));
        oracle = MockPriceOracle(vm.envAddress("ORACLE"));
        btcPx = vm.envOr("BTC_MARK_1E8", uint256(64_808e8));
        ethPx = vm.envOr("ETH_MARK_1E8", uint256(1_832e8));
        btcDump = 60_000e8;
        ethRally = 2_000e8;
        btcId = bytes32(uint256(uint160(vm.envAddress("CHAINLINK_BTC_USD"))));
        ethId = bytes32(uint256(uint160(vm.envAddress("CHAINLINK_ETH_USD"))));
        limitMod = TriggerOrderModule(address(engine.orderModules(OrderKind.Limit)));
        stopMod = TriggerOrderModule(address(engine.orderModules(OrderKind.StopMarket)));
        takeMod = TriggerOrderModule(address(engine.orderModules(OrderKind.TakeMarket)));

        vm.startBroadcast(pk);
        _marks(btcPx, ethPx);
        _openLongEthLimit();
        _openShortBtcLimit();
        _marks(btcDump, ethRally);
        _closeLongEthLimit();
        _closeShortBtcLimit();
        _openLongBtcStop();
        _openShortEthTake();
        vm.stopBroadcast();

        console2.log("long_eth_closed", !engine.positions(LONG_ETH));
        console2.log("short_btc_closed", !engine.positions(SHORT_BTC));
        console2.log("long_stop_btc", engine.positions(LONG_STOP));
        console2.log("short_take_eth", engine.positions(SHORT_TAKE));
        console2.log("usdw_admin", usdw.balanceOf(admin));
        console2.log("usdw_vault", usdw.balanceOf(address(vault)));
        console2.log("example_long_pnl_1k_size", uint256(int256(
            PerpMath.positionPnlUsd(1_000e6, true, ethPx, ethRally)
        )));
        console2.log("example_short_pnl_1k_size", uint256(int256(
            PerpMath.positionPnlUsd(1_000e6, false, btcPx, btcDump)
        )));
    }

    function _proof() internal pure returns (Groth16Proof memory p) {}

    function _marks(uint256 btc, uint256 eth) internal {
        oracle.setPrice(btcId, btc, block.timestamp);
        oracle.setPrice(ethId, eth, block.timestamp);
    }

    function _shield(bytes32 note, uint256 amount) internal {
        vault.shield(_proof(), ShieldPublicInputs({noteCommitment: note, collateralId: 1, amount: amount}));
    }

    function _openLongEthLimit() internal {
        _shield(keccak256("ls-long-eth-note"), 50e6);
        OpenPublicInputs memory o = OpenPublicInputs({
            merkleRoot: vault.currentRoot(),
            noteNullifier: keccak256("ls-long-eth-null"),
            positionCommitment: LONG_ETH,
            changeNoteCommitment: bytes32(0),
            markPrice: ethPx,
            openedAt: block.timestamp,
            marketId: MARKET_ETH,
            collateralId: 1
        });
        // long open limit: fill if mark <= trigger
        uint256 id = limitMod.place(true, true, MARKET_ETH, ethPx, 0, abi.encode(o));
        engine.executeOrder(OrderKind.Limit, _proof(), abi.encode(id));
    }

    function _openShortBtcLimit() internal {
        _shield(keccak256("ls-short-btc-note"), 50e6);
        OpenPublicInputs memory o = OpenPublicInputs({
            merkleRoot: vault.currentRoot(),
            noteNullifier: keccak256("ls-short-btc-null"),
            positionCommitment: SHORT_BTC,
            changeNoteCommitment: bytes32(0),
            markPrice: btcPx,
            openedAt: block.timestamp,
            marketId: MARKET_BTC,
            collateralId: 1
        });
        // short open limit: fill if mark >= trigger
        uint256 id = limitMod.place(true, false, MARKET_BTC, btcPx, 0, abi.encode(o));
        engine.executeOrder(OrderKind.Limit, _proof(), abi.encode(id));
    }

    function _closeLongEthLimit() internal {
        ClosePublicInputs memory c = ClosePublicInputs({
            positionCommitment: LONG_ETH,
            positionNullifier: keccak256("ls-long-eth-pos-null"),
            payoutNoteCommitment: keccak256("ls-long-eth-payout"),
            exitPrice: ethRally,
            protocolFee: 0,
            marketId: MARKET_ETH,
            collateralId: 1
        });
        // long close limit: fill if mark >= trigger (take profit on rally)
        uint256 id = limitMod.place(false, true, MARKET_ETH, ethRally, 0, abi.encode(c));
        engine.executeOrder(OrderKind.Limit, _proof(), abi.encode(id));
    }

    function _closeShortBtcLimit() internal {
        ClosePublicInputs memory c = ClosePublicInputs({
            positionCommitment: SHORT_BTC,
            positionNullifier: keccak256("ls-short-btc-pos-null"),
            payoutNoteCommitment: keccak256("ls-short-btc-payout"),
            exitPrice: btcDump,
            protocolFee: 0,
            marketId: MARKET_BTC,
            collateralId: 1
        });
        // short close limit: fill if mark <= trigger (take profit on dump)
        uint256 id = limitMod.place(false, false, MARKET_BTC, btcDump, 0, abi.encode(c));
        engine.executeOrder(OrderKind.Limit, _proof(), abi.encode(id));
    }

    function _openLongBtcStop() internal {
        _shield(keccak256("ls-long-stop-note"), 50e6);
        OpenPublicInputs memory o = OpenPublicInputs({
            merkleRoot: vault.currentRoot(),
            noteNullifier: keccak256("ls-long-stop-null"),
            positionCommitment: LONG_STOP,
            changeNoteCommitment: bytes32(0),
            markPrice: btcDump,
            openedAt: block.timestamp,
            marketId: MARKET_BTC,
            collateralId: 1
        });
        // long stop open: fill if mark >= trigger
        uint256 id = stopMod.place(true, true, MARKET_BTC, btcDump, 0, abi.encode(o));
        engine.executeOrder(OrderKind.StopMarket, _proof(), abi.encode(id));
    }

    function _openShortEthTake() internal {
        _shield(keccak256("ls-short-take-note"), 50e6);
        OpenPublicInputs memory o = OpenPublicInputs({
            merkleRoot: vault.currentRoot(),
            noteNullifier: keccak256("ls-short-take-null"),
            positionCommitment: SHORT_TAKE,
            changeNoteCommitment: bytes32(0),
            markPrice: ethRally,
            openedAt: block.timestamp,
            marketId: MARKET_ETH,
            collateralId: 1
        });
        // short take: fill if mark <= trigger
        uint256 id = takeMod.place(true, false, MARKET_ETH, ethRally, 0, abi.encode(o));
        engine.executeOrder(OrderKind.TakeMarket, _proof(), abi.encode(id));
    }
}
