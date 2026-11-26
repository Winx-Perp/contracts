// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Auth} from "../lib/Auth.sol";

/// @notice Chainlink-compatible AggregatorV3 for networks without live feeds
/// (Robinhood testnet). Keepers / owner push marks; ChainlinkOracleAdapter reads them.
/// This is not MockPriceOracle — same interface as mainnet Chainlink proxies.
contract AggregatorV3Feed is Auth {
    error InvalidAnswer();

    uint8 public immutable decimals;
    string public description;
    uint256 public version = 1;

    int256 internal _answer;
    uint256 internal _updatedAt;
    uint80 internal _roundId;

    event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 updatedAt);

    constructor(address owner_, uint8 decimals_, string memory description_) Auth(owner_) {
        decimals = decimals_;
        description = description_;
    }

    function setAnswer(int256 answer) external onlyOwnerOrKeeper {
        if (answer <= 0) revert InvalidAnswer();
        _roundId += 1;
        _answer = answer;
        _updatedAt = block.timestamp;
        emit AnswerUpdated(answer, _roundId, _updatedAt);
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, _answer, _updatedAt, _updatedAt, _roundId);
    }

    function getRoundData(uint80)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, _answer, _updatedAt, _updatedAt, _roundId);
    }
}
