// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPnlPool {
    function receiveFee(uint256 amount) external;

    function receiveSeized(uint256 amount) external;
}
