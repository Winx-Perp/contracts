// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPriceOracle} from "../interfaces/IPriceOracle.sol";

/// @notice Test / testnet oracle. Production should wrap Pyth (`PythOracleAdapter`).
contract MockPriceOracle is IPriceOracle {
    error UnknownFeed();

    struct Feed {
        uint256 price;
        uint256 publishTime;
        bool set;
    }

    mapping(bytes32 => Feed) public feeds;

    function setPrice(bytes32 feedId, uint256 price, uint256 publishTime) external {
        feeds[feedId] = Feed({price: price, publishTime: publishTime, set: true});
    }

    function getPrice(bytes32 feedId) external view returns (uint256 price, uint256 publishTime) {
        Feed memory f = feeds[feedId];
        if (!f.set) revert UnknownFeed();
        return (f.price, f.publishTime);
    }
}
