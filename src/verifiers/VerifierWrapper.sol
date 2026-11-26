// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IGroth16Verifier} from "../interfaces/IGroth16Verifier.sol";

/// @notice Pattern for wrapping a snarkjs-generated verifier (fixed-length
/// `uint256[N] input`) behind IGroth16Verifier. Generate the inner contract
/// with `pnpm setup` in privacy_layer, then copy this shape per circuit.
abstract contract VerifierWrapper is IGroth16Verifier {
    error InputLength();

    function expectedInputCount() public pure virtual returns (uint256);

    function verifyGenerated(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[] memory input
    ) internal view virtual returns (bool);

    function verifyProof(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[] calldata input
    ) external view returns (bool) {
        if (input.length != expectedInputCount()) revert InputLength();
        return verifyGenerated(a, b, c, input);
    }
}
