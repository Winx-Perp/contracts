// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PerpEngine} from "../src/PerpEngine.sol";
import {ChainlinkOracleAdapter} from "../src/oracle/ChainlinkOracleAdapter.sol";
import {AggregatorV3Feed} from "../src/oracle/AggregatorV3Feed.sol";

/// Mirror Robinhood mainnet Chainlink BTC/ETH into testnet AggregatorV3 feeds,
/// then point the engine at ChainlinkOracleAdapter + those feed IDs.
contract WireChainlinkMainnet is Script {
    uint32 internal constant MARKET_BTC = 1;
    uint32 internal constant MARKET_ETH = 2;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        PerpEngine engine = PerpEngine(vm.envAddress("ENGINE"));
        address btcFeed = vm.envAddress("BTC_FEED");
        address ethFeed = vm.envAddress("ETH_FEED");
        int256 btcAnswer = vm.envInt("MAINNET_BTC_ANSWER");
        int256 ethAnswer = vm.envInt("MAINNET_ETH_ANSWER");

        vm.startBroadcast(pk);
        ChainlinkOracleAdapter oracle = new ChainlinkOracleAdapter();
        AggregatorV3Feed(btcFeed).setAnswer(btcAnswer);
        AggregatorV3Feed(ethFeed).setAnswer(ethAnswer);
        engine.setOracle(address(oracle));
        engine.setMaxPriceAge(1 hours);
        engine.listMarket(MARKET_BTC, oracle.feedIdOf(btcFeed), 40, 100);
        engine.listMarket(MARKET_ETH, oracle.feedIdOf(ethFeed), 30, 100);
        vm.stopBroadcast();

        (uint256 btcPx, uint256 btcTs) = oracle.getPrice(oracle.feedIdOf(btcFeed));
        (uint256 ethPx, uint256 ethTs) = oracle.getPrice(oracle.feedIdOf(ethFeed));
        console2.log("ORACLE", address(oracle));
        console2.log("BTC_FEED", btcFeed);
        console2.log("ETH_FEED", ethFeed);
        console2.log("btc_1e8", btcPx);
        console2.log("btc_ts", btcTs);
        console2.log("eth_1e8", ethPx);
        console2.log("eth_ts", ethTs);
    }
}
