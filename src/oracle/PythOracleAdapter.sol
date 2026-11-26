// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPriceOracle} from "../interfaces/IPriceOracle.sol";

interface IPyth {
    struct Price {
        int64 price;
        uint64 conf;
        int32 expo;
        uint256 publishTime;
    }

    function getPriceUnsafe(bytes32 id) external view returns (Price memory);
}

/// @notice Normalizes a Pyth feed to a 1e8 unsigned mark price.
/// Wire this on Robinhood Chain once the Pyth contract address is known.
contract PythOracleAdapter is IPriceOracle {
    error InvalidPrice();

    IPyth public immutable pyth;

    constructor(address pyth_) {
        pyth = IPyth(pyth_);
    }

    function getPrice(bytes32 feedId) external view returns (uint256 price, uint256 publishTime) {
        IPyth.Price memory p = pyth.getPriceUnsafe(feedId);
        if (p.price <= 0) revert InvalidPrice();
        price = _to1e8(uint256(uint64(p.price)), p.expo);
        publishTime = p.publishTime;
    }

    function _to1e8(uint256 raw, int32 expo) internal pure returns (uint256) {
        int32 target = -8;
        if (expo == target) return raw;
        if (expo < target) {
            uint256 shift = uint256(uint32(target - expo));
            return raw / (10 ** shift);
        }
        uint256 up = uint256(uint32(expo - target));
        return raw * (10 ** up);
    }
}
