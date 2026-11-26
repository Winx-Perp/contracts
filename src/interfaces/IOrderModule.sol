// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OrderKind} from "../orders/OrderTypes.sol";
import {Groth16Proof} from "../lib/Types.sol";

/// @notice Plug-in for Limit / Stop / Take / TWAP (or a custom kind).
/// The engine calls `execute` only through `PerpEngine.executeOrder`.
/// Implement this, deploy it, then `setOrderModule(kind, address)`.
interface IOrderModule {
    function kind() external view returns (OrderKind);

    function execute(address caller, Groth16Proof calldata proof, bytes calldata data) external;
}
