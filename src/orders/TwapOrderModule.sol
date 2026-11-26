// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PerpEngine} from "../PerpEngine.sol";
import {Groth16Proof, OpenPublicInputs} from "../lib/Types.sol";
import {BaseOrderModule} from "./BaseOrderModule.sol";
import {OrderKind} from "./OrderTypes.sol";

/// @notice Slice an open across `slices` fills, at least `interval` seconds apart.
/// Each fill supplies its own Groth16 proof via executeOrder.
contract TwapOrderModule is BaseOrderModule {
    error NotCreator();
    error Done();
    error TooSoon();

    struct Twap {
        address creator;
        uint32 marketId;
        uint64 slices;
        uint64 filled;
        uint64 interval;
        uint64 nextFillAt;
        bytes payload;
    }

    uint256 public nextId;
    mapping(uint256 => Twap) public orders;

    event Placed(uint256 indexed id, address indexed creator, uint64 slices, uint64 interval);
    event SliceFilled(uint256 indexed id, uint64 filled);

    constructor(address engine_) BaseOrderModule(engine_) {}

    function kind() public pure override returns (OrderKind) {
        return OrderKind.Twap;
    }

    function place(uint32 marketId, uint64 slices, uint64 interval, bytes calldata payload)
        external
        returns (uint256 id)
    {
        require(slices > 0 && interval > 0, "bad twap");
        id = ++nextId;
        orders[id] = Twap({
            creator: msg.sender,
            marketId: marketId,
            slices: slices,
            filled: 0,
            interval: interval,
            nextFillAt: uint64(block.timestamp),
            payload: payload
        });
        emit Placed(id, msg.sender, slices, interval);
    }

    function execute(address, Groth16Proof calldata proof, bytes calldata data) external override onlyEngine {
        uint256 id = abi.decode(data, (uint256));
        Twap storage o = orders[id];
        if (o.creator == address(0)) revert NotCreator();
        if (o.filled >= o.slices) revert Done();
        if (block.timestamp < o.nextFillAt) revert TooSoon();

        OpenPublicInputs memory inputs = abi.decode(o.payload, (OpenPublicInputs));
        PerpEngine(engine).open(proof, inputs);

        o.filled += 1;
        o.nextFillAt = uint64(block.timestamp + o.interval);
        emit SliceFilled(id, o.filled);
    }
}
