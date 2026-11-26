// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    ClosePublicInputs,
    DecreasePublicInputs,
    HealthPublicInputs,
    IncreasePublicInputs,
    LiquidatePublicInputs,
    OpenPublicInputs,
    ShieldPublicInputs,
    UnshieldPublicInputs
} from "./Types.sol";

/// Packs circuit public inputs. Last signal is always `scope`.
library PublicInputs {
    function packShield(ShieldPublicInputs memory p, uint256 scope) internal pure returns (uint256[] memory input) {
        input = new uint256[](4);
        input[0] = uint256(p.noteCommitment);
        input[1] = p.amount;
        input[2] = p.collateralId;
        input[3] = scope;
    }

    function packUnshield(UnshieldPublicInputs memory p, uint256 scope) internal pure returns (uint256[] memory input) {
        input = new uint256[](6);
        input[0] = uint256(p.merkleRoot);
        input[1] = uint256(p.noteNullifier);
        input[2] = p.amount;
        input[3] = uint256(uint160(p.recipient));
        input[4] = p.collateralId;
        input[5] = scope;
    }

    function packOpen(
        OpenPublicInputs memory p,
        uint256 maxLeverage,
        int256 fundingIndex,
        uint256 impactBps,
        uint256 scope
    ) internal pure returns (uint256[] memory input) {
        input = new uint256[](12);
        input[0] = uint256(p.merkleRoot);
        input[1] = uint256(p.noteNullifier);
        input[2] = uint256(p.positionCommitment);
        input[3] = uint256(p.changeNoteCommitment);
        input[4] = p.markPrice;
        input[5] = maxLeverage;
        input[6] = p.marketId;
        input[7] = _signed(fundingIndex);
        input[8] = impactBps;
        input[9] = p.openedAt;
        input[10] = p.collateralId;
        input[11] = scope;
    }

    function packClose(
        ClosePublicInputs memory p,
        int256 fundingIndex,
        uint256 impactBps,
        uint256 closedAt,
        uint256 borrowRate,
        uint256 profitFeeBps,
        uint256 scope
    ) internal pure returns (uint256[] memory input) {
        input = new uint256[](13);
        input[0] = uint256(p.positionCommitment);
        input[1] = uint256(p.positionNullifier);
        input[2] = uint256(p.payoutNoteCommitment);
        input[3] = p.exitPrice;
        input[4] = p.protocolFee;
        input[5] = p.marketId;
        input[6] = p.collateralId;
        input[7] = _signed(fundingIndex);
        input[8] = impactBps;
        input[9] = closedAt;
        input[10] = borrowRate;
        input[11] = profitFeeBps;
        input[12] = scope;
    }

    function packLiquidate(
        LiquidatePublicInputs memory p,
        uint256 mmBps,
        int256 fundingIndex,
        uint256 impactBps,
        uint256 closedAt,
        uint256 borrowRate,
        uint256 scope
    ) internal pure returns (uint256[] memory input) {
        input = new uint256[](13);
        input[0] = uint256(p.positionCommitment);
        input[1] = uint256(p.positionNullifier);
        input[2] = uint256(p.leftoverNoteCommitment);
        input[3] = p.exitPrice;
        input[4] = p.seizedAmount;
        input[5] = mmBps;
        input[6] = p.marketId;
        input[7] = _signed(fundingIndex);
        input[8] = impactBps;
        input[9] = closedAt;
        input[10] = borrowRate;
        input[11] = p.collateralId;
        input[12] = scope;
    }

    function packIncrease(
        IncreasePublicInputs memory p,
        uint256 maxLeverage,
        int256 fundingIndex,
        uint256 impactBps,
        uint256 nowTs,
        uint256 scope
    ) internal pure returns (uint256[] memory input) {
        input = new uint256[](14);
        input[0] = uint256(p.merkleRoot);
        input[1] = uint256(p.extraNoteNullifier);
        input[2] = uint256(p.oldPositionCommitment);
        input[3] = uint256(p.oldPositionNullifier);
        input[4] = uint256(p.newPositionCommitment);
        input[5] = uint256(p.changeNoteCommitment);
        input[6] = p.markPrice;
        input[7] = maxLeverage;
        input[8] = p.marketId;
        input[9] = _signed(fundingIndex);
        input[10] = impactBps;
        input[11] = nowTs;
        input[12] = p.collateralId;
        input[13] = scope;
    }

    function packDecrease(
        DecreasePublicInputs memory p,
        int256 fundingIndex,
        uint256 impactBps,
        uint256 closedAt,
        uint256 borrowRate,
        uint256 profitFeeBps,
        uint256 scope
    ) internal pure returns (uint256[] memory input) {
        input = new uint256[](14);
        input[0] = uint256(p.oldPositionCommitment);
        input[1] = uint256(p.oldPositionNullifier);
        input[2] = uint256(p.newPositionCommitment);
        input[3] = uint256(p.payoutNoteCommitment);
        input[4] = p.exitPrice;
        input[5] = p.protocolFee;
        input[6] = p.marketId;
        input[7] = p.collateralId;
        input[8] = _signed(fundingIndex);
        input[9] = impactBps;
        input[10] = closedAt;
        input[11] = borrowRate;
        input[12] = profitFeeBps;
        input[13] = scope;
    }

    function packHealth(
        HealthPublicInputs memory p,
        uint256 mmBps,
        int256 fundingIndex,
        uint256 impactBps,
        uint256 nowTs,
        uint256 borrowRate,
        uint256 scope
    ) internal pure returns (uint256[] memory input) {
        input = new uint256[](11);
        input[0] = uint256(p.positionCommitment);
        input[1] = uint256(p.healthCommitment);
        input[2] = p.liquidatable;
        input[3] = p.markPrice;
        input[4] = mmBps;
        input[5] = p.marketId;
        input[6] = _signed(fundingIndex);
        input[7] = impactBps;
        input[8] = nowTs;
        input[9] = borrowRate;
        input[10] = scope;
    }

    function _signed(int256 v) private pure returns (uint256) {
        return v >= 0 ? uint256(v) : uint256(-v);
    }
}
