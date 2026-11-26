// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PerpEngine} from "../src/PerpEngine.sol";
import {PythOracleAdapter} from "../src/oracle/PythOracleAdapter.sol";

/// Point live engine at Pyth Core on Robinhood testnet + relist BTC/ETH with Pyth feed IDs.
contract WirePythOracle is Script {
    // Pyth Core Compatible — Robinhood Chain Testnet
    address internal constant PYTH_CORE = 0x8250f4aF4B972684F7b336503E2D6dFeDeB1487a;

    bytes32 internal constant PYTH_BTC =
        0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43;
    bytes32 internal constant PYTH_ETH =
        0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;

    uint32 internal constant MARKET_BTC = 1;
    uint32 internal constant MARKET_ETH = 2;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        PerpEngine engine = PerpEngine(vm.envAddress("ENGINE"));

        vm.startBroadcast(pk);
        PythOracleAdapter oracle = new PythOracleAdapter(PYTH_CORE);
        engine.setOracle(address(oracle));
        // Allow brief Hermes lag; Pyth publishTime is wall-clock.
        engine.setMaxPriceAge(1 hours);
        engine.listMarket(MARKET_BTC, PYTH_BTC, 40, 100);
        engine.listMarket(MARKET_ETH, PYTH_ETH, 30, 100);
        vm.stopBroadcast();

        (uint256 btcPx, uint256 btcTs) = oracle.getPrice(PYTH_BTC);
        (uint256 ethPx, uint256 ethTs) = oracle.getPrice(PYTH_ETH);

        console2.log("ORACLE", address(oracle));
        console2.log("PYTH_CORE", PYTH_CORE);
        console2.log("btc_1e8", btcPx);
        console2.log("btc_publishTime", btcTs);
        console2.log("eth_1e8", ethPx);
        console2.log("eth_publishTime", ethTs);
        console2.logBytes32(engine.marketFeed(MARKET_BTC));
        console2.logBytes32(engine.marketFeed(MARKET_ETH));
    }
}
