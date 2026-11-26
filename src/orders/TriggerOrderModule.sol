// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {PerpEngine} from "../PerpEngine.sol";
import {ClosePublicInputs, Groth16Proof, OpenPublicInputs} from "../lib/Types.sol";
import {BaseOrderModule} from "./BaseOrderModule.sol";
import {OrderKind} from "./OrderTypes.sol";

/// @notice Limit / Stop Market / Take Market / Stop Limit / Take Limit.
/// Place on this contract, fill via `engine.executeOrder(kind, proof, abi.encode(id))`.
contract TriggerOrderModule is BaseOrderModule {
    error NotCreator();
    error Executed();
    error Cancelled();
    error TriggerNotMet();
    error LimitNotMet();
    error BadKind();

    struct Order {
        address creator;
        bool isOpen;
        bool isLong;
        bool executed;
        bool cancelled;
        uint32 marketId;
        uint256 triggerPrice;
        uint256 limitPrice;
        bytes payload;
    }

    OrderKind public immutable configuredKind;
    uint256 public nextId;
    mapping(uint256 => Order) public orders;

    event Placed(uint256 indexed id, address indexed creator, bool isOpen, bool isLong);
    event CancelledOrder(uint256 indexed id);
    event Filled(uint256 indexed id);

    constructor(address engine_, OrderKind kind_) BaseOrderModule(engine_) {
        if (
            kind_ != OrderKind.Limit && kind_ != OrderKind.StopMarket && kind_ != OrderKind.TakeMarket
                && kind_ != OrderKind.StopLimit && kind_ != OrderKind.TakeLimit
        ) revert BadKind();
        configuredKind = kind_;
    }

    function kind() public view override returns (OrderKind) {
        return configuredKind;
    }

    function place(
        bool isOpen,
        bool isLong,
        uint32 marketId,
        uint256 triggerPrice,
        uint256 limitPrice,
        bytes calldata payload
    ) external returns (uint256 id) {
        id = ++nextId;
        orders[id] = Order({
            creator: msg.sender,
            isOpen: isOpen,
            isLong: isLong,
            executed: false,
            cancelled: false,
            marketId: marketId,
            triggerPrice: triggerPrice,
            limitPrice: limitPrice,
            payload: payload
        });
        emit Placed(id, msg.sender, isOpen, isLong);
    }

    function cancel(uint256 id) external {
        Order storage o = orders[id];
        if (o.creator != msg.sender) revert NotCreator();
        if (o.executed) revert Executed();
        o.cancelled = true;
        emit CancelledOrder(id);
    }

    function execute(address, Groth16Proof calldata proof, bytes calldata data) external override onlyEngine {
        uint256 id = abi.decode(data, (uint256));
        Order storage o = orders[id];
        if (o.creator == address(0) || o.cancelled) revert Cancelled();
        if (o.executed) revert Executed();

        PerpEngine eng = PerpEngine(engine);
        (uint256 price,) = IPriceOracle(eng.oracle()).getPrice(eng.marketFeed(o.marketId));
        _checkTrigger(o, price);
        o.executed = true;

        if (o.isOpen) {
            OpenPublicInputs memory inputs = abi.decode(o.payload, (OpenPublicInputs));
            eng.open(proof, inputs);
        } else {
            ClosePublicInputs memory inputs = abi.decode(o.payload, (ClosePublicInputs));
            eng.close(proof, inputs);
        }
        emit Filled(id);
    }

    function _checkTrigger(Order storage o, uint256 price) internal view {
        OrderKind k = configuredKind;
        bool long = o.isLong;
        bool opening = o.isOpen;

        if (k == OrderKind.Limit) {
            bool ok = long
                ? (opening ? price <= o.triggerPrice : price >= o.triggerPrice)
                : (opening ? price >= o.triggerPrice : price <= o.triggerPrice);
            if (!ok) revert TriggerNotMet();
            return;
        }

        if (k == OrderKind.StopMarket) {
            bool ok = long
                ? (opening ? price >= o.triggerPrice : price <= o.triggerPrice)
                : (opening ? price <= o.triggerPrice : price >= o.triggerPrice);
            if (!ok) revert TriggerNotMet();
            return;
        }

        if (k == OrderKind.TakeMarket) {
            bool ok = long ? price >= o.triggerPrice : price <= o.triggerPrice;
            if (!ok) revert TriggerNotMet();
            return;
        }

        bool stopHit = long
            ? (opening ? price >= o.triggerPrice : price <= o.triggerPrice)
            : (opening ? price <= o.triggerPrice : price >= o.triggerPrice);
        if (!stopHit) revert TriggerNotMet();

        if (k == OrderKind.StopLimit || k == OrderKind.TakeLimit) {
            bool limitOk = long ? price <= o.limitPrice : price >= o.limitPrice;
            if (!limitOk) revert LimitNotMet();
        }
    }
}
