// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IOrderModule} from "../interfaces/IOrderModule.sol";
import {OrderKind} from "./OrderTypes.sol";
import {Groth16Proof} from "../lib/Types.sol";

/// @notice Inherit this, override `kind` and `execute`, then register on PerpEngine.
/// `execute` only runs when the engine forwards a call (not via a direct poke).
abstract contract BaseOrderModule is IOrderModule {
    error NotEngine();

    address public immutable engine;

    constructor(address engine_) {
        engine = engine_;
    }

    modifier onlyEngine() {
        if (msg.sender != engine) revert NotEngine();
        _;
    }

    function kind() public view virtual returns (OrderKind);

    function execute(address caller, Groth16Proof calldata proof, bytes calldata data) external virtual onlyEngine {}
}
