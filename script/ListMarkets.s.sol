// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PerpEngine} from "../src/PerpEngine.sol";
import {AggregatorV3Feed} from "../src/oracle/AggregatorV3Feed.sol";

/// Lists new perp markets on the existing engine. Does not redeploy it.
contract ListMarkets is Script {
    PerpEngine internal constant ENGINE = PerpEngine(0x5135288399BCdDa309A5299244c46958477B7d91);

    struct Row {
        uint32 id;
        uint32 lev;
        int256 px;
        string desc;
        string key;
    }

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address admin = vm.addr(pk);
        Row[] memory rows = _rows();

        vm.startBroadcast(pk);
        for (uint256 i = 0; i < rows.length; i++) {
            AggregatorV3Feed feed = new AggregatorV3Feed(admin, 8, rows[i].desc);
            feed.setAnswer(rows[i].px);
            ENGINE.listMarket(rows[i].id, bytes32(uint256(uint160(address(feed)))), rows[i].lev, 100);
            console2.log("LISTED", rows[i].key, address(feed));
        }
        vm.stopBroadcast();
    }

    function _rows() internal pure returns (Row[] memory rows) {
        rows = new Row[](16);
        rows[0] = Row(3, 40, 55_427_240_535, "BNB / USD", "bnb");
        rows[1] = Row(4, 30, 95_297_640, "XRP / USD", "xrp");
        rows[2] = Row(5, 50, 7_078_782_375, "SOL / USD", "sol");
        rows[3] = Row(6, 30, 30_340_635, "TRX / USD", "trx");
        rows[4] = Row(7, 30, 6_116_217_787, "HYPE / USD", "hype");
        rows[5] = Row(8, 30, 74_723_177_304, "ZEC / USD", "zec");
        rows[6] = Row(9, 30, 52_241_164_235, "XMR / USD", "xmr");
        rows[7] = Row(10, 30, 5_646_047, "DOGE / USD", "doge");
        rows[8] = Row(11, 10, 14_316_589_039, "NVDA / USD", "nvda");
        rows[9] = Row(12, 10, 12_899_500_000, "SPCX / USD", "spcx");
        rows[10] = Row(13, 10, 63_209_206_728, "META / USD", "meta");
        rows[11] = Row(14, 10, 10_174_000_000, "COIN / USD", "coin");
        rows[12] = Row(15, 10, 3_383_500_000, "TTEQ / USD", "tteq");
        rows[13] = Row(16, 10, 38_445_000_000, "TSLA / USD", "tsla");
        rows[14] = Row(17, 10, 27_740_378_494, "GOOGL / USD", "googl");
        rows[15] = Row(18, 10, 34_816_930_567, "AAPL / USD", "aapl");
    }
}
