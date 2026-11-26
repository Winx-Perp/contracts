// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IVault {
    function spendNote(bytes32 nullifier, bytes32 changeCommitment, bytes32 merkleRoot) external;

    function insertNote(bytes32 commitment) external;

    /// @notice Move USDW (or other collateral) to the PnL pool for fees / seized margin.
    function payProtocol(uint32 collateralId, address to, uint256 amount) external;

    function isLiveNote(bytes32 commitment) external view returns (bool);

    function isSpentNullifier(bytes32 nullifier) external view returns (bool);

    function isKnownRoot(bytes32 root) external view returns (bool);

    function currentRoot() external view returns (bytes32);

    function marginEnabled(uint32 collateralId) external view returns (bool);
}
