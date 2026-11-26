// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IGroth16Verifier} from "../interfaces/IGroth16Verifier.sol";

/// @notice Always-true verifier for protocol tests before the trusted setup
/// produces circuit-specific Groth16 verifying keys.
contract MockVerifier is IGroth16Verifier {
    bool public shouldPass = true;

    function setShouldPass(bool value) external {
        shouldPass = value;
    }

    function verifyProof(uint256[2] calldata, uint256[2][2] calldata, uint256[2] calldata, uint256[] calldata)
        external
        view
        returns (bool)
    {
        return shouldPass;
    }
}
