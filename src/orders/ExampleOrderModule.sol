// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseOrderModule} from "./BaseOrderModule.sol";
import {OrderKind} from "./OrderTypes.sol";
import {Groth16Proof} from "../lib/Types.sol";

/// @notice Copy this for Limit / Stop / Take / TWAP. Override `kind` and put
/// your trigger + proof checks in `execute`. Register with:
///   engine.setOrderModule(module.kind(), address(module));
contract ExampleOrderModule is BaseOrderModule {
    OrderKind public immutable configuredKind;

    event OrderExecuted(address indexed caller, bytes data);

    constructor(address engine_, OrderKind kind_) BaseOrderModule(engine_) {
        configuredKind = kind_;
    }

    function kind() public view override returns (OrderKind) {
        return configuredKind;
    }

    function execute(address caller, Groth16Proof calldata, bytes calldata data) external override onlyEngine {
        emit OrderExecuted(caller, data);
    }
}
