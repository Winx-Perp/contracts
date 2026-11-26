// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPriceOracle} from "../interfaces/IPriceOracle.sol";

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

/// @notice Robinhood Chain on-chain prices are Chainlink `AggregatorV3`.
/// `feedId` is the feed proxy address left-padded to bytes32 (see `feedIdOf`).
/// https://docs.robinhood.com/chain/oracles-and-price-feeds
contract ChainlinkOracleAdapter is IPriceOracle {
    error InvalidPrice();
    error InvalidFeed();

    function feedIdOf(address feed) public pure returns (bytes32) {
        return bytes32(uint256(uint160(feed)));
    }

    function feedOf(bytes32 feedId) public pure returns (address) {
        return address(uint160(uint256(feedId)));
    }

    function getPrice(bytes32 feedId) external view returns (uint256 price, uint256 publishTime) {
        address feed = feedOf(feedId);
        if (feed == address(0)) revert InvalidFeed();
        (, int256 answer,, uint256 updatedAt,) = AggregatorV3Interface(feed).latestRoundData();
        if (answer <= 0 || updatedAt == 0) revert InvalidPrice();
        uint8 dec = AggregatorV3Interface(feed).decimals();
        price = _to1e8(uint256(answer), dec);
        publishTime = updatedAt;
    }

    function _to1e8(uint256 raw, uint8 dec) internal pure returns (uint256) {
        if (dec == 8) return raw;
        if (dec < 8) return raw * (10 ** (8 - dec));
        return raw / (10 ** (dec - 8));
    }
}
