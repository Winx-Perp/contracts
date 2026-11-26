// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

struct Groth16Proof {
    uint256[2] a;
    uint256[2][2] b;
    uint256[2] c;
}

struct Market {
    bytes32 pythFeedId;
    uint32 maxLeverage;
    uint32 maintenanceMarginBps;
    bool listed;
    uint256 fundingFactorPerSecond;
    uint256 borrowFactorPerSecond;
    uint256 impactFactorBps;
    uint256 epochDuration;
    uint256 epochStart;
    uint256 longOi;
    uint256 shortOi;
    int256 fundingIndexLong;
    int256 fundingIndexShort;
}

struct Collateral {
    address token;
    uint8 decimals;
    bool listed;
    bool marginEnabled;
}

struct ShieldPublicInputs {
    bytes32 noteCommitment;
    uint32 collateralId;
    uint256 amount;
}

struct UnshieldPublicInputs {
    bytes32 merkleRoot;
    bytes32 noteNullifier;
    uint32 collateralId;
    uint256 amount;
    address recipient;
}

struct OpenPublicInputs {
    bytes32 merkleRoot;
    bytes32 noteNullifier;
    bytes32 positionCommitment;
    bytes32 changeNoteCommitment;
    uint256 markPrice;
    /// @notice Must match the circuit witness; engine allows a short skew vs block.timestamp.
    uint256 openedAt;
    uint32 marketId;
    uint32 collateralId;
}

struct ClosePublicInputs {
    bytes32 positionCommitment;
    bytes32 positionNullifier;
    bytes32 payoutNoteCommitment;
    uint256 exitPrice;
    /// @notice 0.1% of positive PnL (10 bps). Public so the engine can pay the pool.
    uint256 protocolFee;
    uint32 marketId;
    uint32 collateralId;
}

struct LiquidatePublicInputs {
    bytes32 positionCommitment;
    bytes32 positionNullifier;
    bytes32 leftoverNoteCommitment;
    uint256 exitPrice;
    /// @notice Margin not returned to the trader; credited to the PnL pool.
    uint256 seizedAmount;
    uint32 marketId;
    uint32 collateralId;
    /// @notice Timestamp the proof was built at. Engine allows skew of `maxLiqAge`.
    uint256 closedAt;
}

struct IncreasePublicInputs {
    bytes32 merkleRoot;
    bytes32 extraNoteNullifier;
    bytes32 oldPositionCommitment;
    bytes32 oldPositionNullifier;
    bytes32 newPositionCommitment;
    bytes32 changeNoteCommitment;
    uint256 markPrice;
    uint32 marketId;
    uint32 collateralId;
}

struct DecreasePublicInputs {
    bytes32 oldPositionCommitment;
    bytes32 oldPositionNullifier;
    bytes32 newPositionCommitment;
    bytes32 payoutNoteCommitment;
    uint256 exitPrice;
    uint256 protocolFee;
    uint32 marketId;
    uint32 collateralId;
}

struct HealthPublicInputs {
    bytes32 positionCommitment;
    bytes32 healthCommitment;
    uint256 liquidatable;
    uint256 markPrice;
    uint32 marketId;
}

struct EngineVerifiers {
    address open;
    address close;
    address liquidate;
    address increase;
    address decrease;
    address health;
}

struct HealthState {
    bytes32 commitment;
    bool liquidatable;
    uint64 updatedAt;
}
