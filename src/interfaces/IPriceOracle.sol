// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Mark price in 1e8, plus the feed's publish time for staleness checks.
interface IPriceOracle {
    function getPrice(bytes32 feedId) external view returns (uint256 price, uint256 publishTime);
}
