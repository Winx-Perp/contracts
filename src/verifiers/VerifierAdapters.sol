// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IGroth16Verifier} from "../interfaces/IGroth16Verifier.sol";
import {ShieldVerifier} from "./generated/ShieldVerifier.sol";
import {UnshieldVerifier} from "./generated/UnshieldVerifier.sol";
import {OpenVerifier} from "./generated/OpenVerifier.sol";
import {CloseVerifier} from "./generated/CloseVerifier.sol";
import {LiquidateVerifier} from "./generated/LiquidateVerifier.sol";
import {IncreaseVerifier} from "./generated/IncreaseVerifier.sol";
import {DecreaseVerifier} from "./generated/DecreaseVerifier.sol";
import {HealthVerifier} from "./generated/HealthVerifier.sol";

/// Adapters: snarkjs fixed-length `uint[N]` → IGroth16Verifier dynamic `uint256[]`.

error BadInputLength();

contract ShieldVerifierAdapter is IGroth16Verifier {
    ShieldVerifier public immutable inner;

    constructor(address inner_) {
        inner = ShieldVerifier(inner_);
    }

    function verifyProof(uint256[2] calldata a, uint256[2][2] calldata b, uint256[2] calldata c, uint256[] calldata input)
        external
        view
        returns (bool)
    {
        if (input.length != 4) revert BadInputLength();
        return inner.verifyProof(a, b, c, [input[0], input[1], input[2], input[3]]);
    }
}

contract UnshieldVerifierAdapter is IGroth16Verifier {
    UnshieldVerifier public immutable inner;

    constructor(address inner_) {
        inner = UnshieldVerifier(inner_);
    }

    function verifyProof(uint256[2] calldata a, uint256[2][2] calldata b, uint256[2] calldata c, uint256[] calldata input)
        external
        view
        returns (bool)
    {
        if (input.length != 6) revert BadInputLength();
        return inner.verifyProof(a, b, c, [input[0], input[1], input[2], input[3], input[4], input[5]]);
    }
}

contract OpenVerifierAdapter is IGroth16Verifier {
    OpenVerifier public immutable inner;

    constructor(address inner_) {
        inner = OpenVerifier(inner_);
    }

    function verifyProof(uint256[2] calldata a, uint256[2][2] calldata b, uint256[2] calldata c, uint256[] calldata input)
        external
        view
        returns (bool)
    {
        if (input.length != 12) revert BadInputLength();
        uint256[12] memory pub;
        for (uint256 i; i < 12; ++i) pub[i] = input[i];
        return inner.verifyProof(a, b, c, pub);
    }
}

contract CloseVerifierAdapter is IGroth16Verifier {
    CloseVerifier public immutable inner;

    constructor(address inner_) {
        inner = CloseVerifier(inner_);
    }

    function verifyProof(uint256[2] calldata a, uint256[2][2] calldata b, uint256[2] calldata c, uint256[] calldata input)
        external
        view
        returns (bool)
    {
        if (input.length != 13) revert BadInputLength();
        uint256[13] memory pub;
        for (uint256 i; i < 13; ++i) pub[i] = input[i];
        return inner.verifyProof(a, b, c, pub);
    }
}

contract LiquidateVerifierAdapter is IGroth16Verifier {
    LiquidateVerifier public immutable inner;

    constructor(address inner_) {
        inner = LiquidateVerifier(inner_);
    }

    function verifyProof(uint256[2] calldata a, uint256[2][2] calldata b, uint256[2] calldata c, uint256[] calldata input)
        external
        view
        returns (bool)
    {
        if (input.length != 13) revert BadInputLength();
        uint256[13] memory pub;
        for (uint256 i; i < 13; ++i) pub[i] = input[i];
        return inner.verifyProof(a, b, c, pub);
    }
}

contract IncreaseVerifierAdapter is IGroth16Verifier {
    IncreaseVerifier public immutable inner;

    constructor(address inner_) {
        inner = IncreaseVerifier(inner_);
    }

    function verifyProof(uint256[2] calldata a, uint256[2][2] calldata b, uint256[2] calldata c, uint256[] calldata input)
        external
        view
        returns (bool)
    {
        if (input.length != 14) revert BadInputLength();
        uint256[14] memory pub;
        for (uint256 i; i < 14; ++i) pub[i] = input[i];
        return inner.verifyProof(a, b, c, pub);
    }
}

contract DecreaseVerifierAdapter is IGroth16Verifier {
    DecreaseVerifier public immutable inner;

    constructor(address inner_) {
        inner = DecreaseVerifier(inner_);
    }

    function verifyProof(uint256[2] calldata a, uint256[2][2] calldata b, uint256[2] calldata c, uint256[] calldata input)
        external
        view
        returns (bool)
    {
        if (input.length != 14) revert BadInputLength();
        uint256[14] memory pub;
        for (uint256 i; i < 14; ++i) pub[i] = input[i];
        return inner.verifyProof(a, b, c, pub);
    }
}

contract HealthVerifierAdapter is IGroth16Verifier {
    HealthVerifier public immutable inner;

    constructor(address inner_) {
        inner = HealthVerifier(inner_);
    }

    function verifyProof(uint256[2] calldata a, uint256[2][2] calldata b, uint256[2] calldata c, uint256[] calldata input)
        external
        view
        returns (bool)
    {
        if (input.length != 11) revert BadInputLength();
        uint256[11] memory pub;
        for (uint256 i; i < 11; ++i) pub[i] = input[i];
        return inner.verifyProof(a, b, c, pub);
    }
}
