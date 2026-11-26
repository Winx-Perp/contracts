// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IHasher {
    function hashLeftRight(bytes32 left, bytes32 right) external view returns (bytes32);
}

/// @notice Default tree hasher for unit tests. Production uses PoseidonHasher.
contract KeccakHasher is IHasher {
    function hashLeftRight(bytes32 left, bytes32 right) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(left, right));
    }
}

interface IPoseidon2 {
    function poseidon(uint256[2] memory input) external pure returns (uint256);
}

/// @notice Circomlib Poseidon(2) — matches privacy_layer MerkleProof.
contract PoseidonHasher is IHasher {
    IPoseidon2 public immutable poseidon2;

    constructor(address poseidon2_) {
        poseidon2 = IPoseidon2(poseidon2_);
    }

    function hashLeftRight(bytes32 left, bytes32 right) external view returns (bytes32) {
        return bytes32(poseidon2.poseidon([uint256(left), uint256(right)]));
    }
}
