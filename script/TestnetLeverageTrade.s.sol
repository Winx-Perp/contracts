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

/// Set BTC 40x / ETH 30x, then long/short through two price paths and log PnL.
contract TestnetLeverageTrade is Script {
    uint32 internal constant MARKET_BTC = 1;
    uint32 internal constant MARKET_ETH = 2;
    uint256 internal constant MARGIN = 100e6;

    bytes32 internal constant LONG_ETH_30 = keccak256("lev-long-eth-30");
    bytes32 internal constant SHORT_BTC_40 = keccak256("lev-short-btc-40");
    bytes32 internal constant SHORT_ETH_30 = keccak256("lev-short-eth-30");
    bytes32 internal constant LONG_BTC_40 = keccak256("lev-long-btc-40");

    USDW internal usdw;
    Vault internal vault;
    PerpEngine internal engine;
    MockPriceOracle internal oracle;
    TriggerOrderModule internal limitMod;
    bytes32 internal btcId;
    bytes32 internal ethId;

    uint256 internal constant ETH_ENTRY = 1_832e8;
    uint256 internal constant ETH_RALLY = 2_000e8;
    uint256 internal constant ETH_DUMP = 1_700e8;
    uint256 internal constant BTC_ENTRY = 64_808e8;
    uint256 internal constant BTC_DUMP = 60_000e8;
    uint256 internal constant BTC_RALLY = 70_000e8;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        usdw = USDW(vm.envAddress("USDW"));
        vault = Vault(vm.envAddress("VAULT"));
        engine = PerpEngine(vm.envAddress("ENGINE"));
        oracle = MockPriceOracle(vm.envAddress("ORACLE"));
        btcId = bytes32(uint256(uint160(vm.envAddress("CHAINLINK_BTC_USD"))));
        ethId = bytes32(uint256(uint160(vm.envAddress("CHAINLINK_ETH_USD"))));
        limitMod = TriggerOrderModule(address(engine.orderModules(OrderKind.Limit)));

        vm.startBroadcast(pk);
        _list();
        _round1();
        _round2();
        vm.stopBroadcast();

        _logPnl();
        console2.log("long_eth_closed", !engine.positions(LONG_ETH_30));
        console2.log("short_btc_closed", !engine.positions(SHORT_BTC_40));
        console2.log("short_eth_closed", !engine.positions(SHORT_ETH_30));
        console2.log("long_btc_closed", !engine.positions(LONG_BTC_40));
        console2.log("usdw_vault", usdw.balanceOf(address(vault)));
    }

    function _proof() internal pure returns (Groth16Proof memory p) {}

    function _list() internal {
        engine.listMarket(MARKET_BTC, btcId, 40, 100);
        engine.listMarket(MARKET_ETH, ethId, 30, 100);
    }

    function _marks(uint256 btc, uint256 eth) internal {
        oracle.setPrice(btcId, btc, block.timestamp);
        oracle.setPrice(ethId, eth, block.timestamp);
    }

    function _round1() internal {
        _marks(BTC_ENTRY, ETH_ENTRY);
        _open(true, MARKET_ETH, ETH_ENTRY, LONG_ETH_30, keccak256("lev-long-eth-note"));
        _open(false, MARKET_BTC, BTC_ENTRY, SHORT_BTC_40, keccak256("lev-short-btc-note"));
        _marks(BTC_DUMP, ETH_RALLY);
        _close(true, MARKET_ETH, ETH_RALLY, LONG_ETH_30, keccak256("lev-long-eth-pos-null"));
        _close(false, MARKET_BTC, BTC_DUMP, SHORT_BTC_40, keccak256("lev-short-btc-pos-null"));
    }

    function _round2() internal {
        _open(false, MARKET_ETH, ETH_RALLY, SHORT_ETH_30, keccak256("lev-short-eth-note"));
        _open(true, MARKET_BTC, BTC_DUMP, LONG_BTC_40, keccak256("lev-long-btc-note"));
        _marks(BTC_RALLY, ETH_DUMP);
        _close(false, MARKET_ETH, ETH_DUMP, SHORT_ETH_30, keccak256("lev-short-eth-pos-null"));
        _close(true, MARKET_BTC, BTC_RALLY, LONG_BTC_40, keccak256("lev-long-btc-pos-null"));
    }

    function _open(bool isLong, uint32 market, uint256 mark, bytes32 pos, bytes32 note) internal {
        vault.shield(_proof(), ShieldPublicInputs({noteCommitment: note, collateralId: 1, amount: MARGIN}));
        OpenPublicInputs memory o = OpenPublicInputs({
            merkleRoot: vault.currentRoot(),
            noteNullifier: keccak256(abi.encodePacked(note, "null")),
            positionCommitment: pos,
            changeNoteCommitment: bytes32(0),
            markPrice: mark,
            openedAt: block.timestamp,
            marketId: market,
            collateralId: 1
        });
        uint256 id = limitMod.place(true, isLong, market, mark, 0, abi.encode(o));
        engine.executeOrder(OrderKind.Limit, _proof(), abi.encode(id));
    }

    function _close(bool isLong, uint32 market, uint256 exit, bytes32 pos, bytes32 posNull) internal {
        ClosePublicInputs memory c = ClosePublicInputs({
            positionCommitment: pos,
            positionNullifier: posNull,
            payoutNoteCommitment: keccak256(abi.encodePacked(pos, "payout")),
            exitPrice: exit,
            protocolFee: 0,
            marketId: market,
            collateralId: 1
        });
        uint256 id = limitMod.place(false, isLong, market, exit, 0, abi.encode(c));
        engine.executeOrder(OrderKind.Limit, _proof(), abi.encode(id));
    }

    function _logPnl() internal pure {
        _logOne("ETH_long_10x", PerpMath.positionPnlUsd(MARGIN * 10, true, ETH_ENTRY, ETH_RALLY));
        _logOne("ETH_long_30x", PerpMath.positionPnlUsd(MARGIN * 30, true, ETH_ENTRY, ETH_RALLY));
        _logOne("ETH_short_30x_on_rally_LOSS", PerpMath.positionPnlUsd(MARGIN * 30, false, ETH_ENTRY, ETH_RALLY));
        _logOne("BTC_short_10x", PerpMath.positionPnlUsd(MARGIN * 10, false, BTC_ENTRY, BTC_DUMP));
        _logOne("BTC_short_40x", PerpMath.positionPnlUsd(MARGIN * 40, false, BTC_ENTRY, BTC_DUMP));
        _logOne("BTC_long_40x_on_dump_LOSS", PerpMath.positionPnlUsd(MARGIN * 40, true, BTC_ENTRY, BTC_DUMP));
        _logOne("ETH_short_30x_2000_to_1700", PerpMath.positionPnlUsd(MARGIN * 30, false, ETH_RALLY, ETH_DUMP));
        _logOne("BTC_long_40x_60000_to_70000", PerpMath.positionPnlUsd(MARGIN * 40, true, BTC_DUMP, BTC_RALLY));
    }

    function _logOne(string memory label, int256 pnl) internal pure {
        if (pnl >= 0) console2.log(label, uint256(pnl));
        else console2.log(label, uint256(-pnl));
    }
}
