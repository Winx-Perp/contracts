// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Queue-and-execute delay. Set this contract as `owner` of Vault/Engine
/// so admin calls (listMarket, setVerifiers, …) wait `delay` seconds.
contract Timelock {
    error NotAdmin();
    error NotReady();
    error UnknownTx();
    error AlreadyQueued();
    error ZeroAddress();

    address public admin;
    uint256 public delay;
    mapping(bytes32 => uint256) public eta;

    event Queued(bytes32 indexed id, address target, bytes data, uint256 eta);
    event Executed(bytes32 indexed id, address target, bytes data);
    event Cancelled(bytes32 indexed id);
    event DelayUpdated(uint256 delay);
    event AdminUpdated(address admin);

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    constructor(address admin_, uint256 delay_) {
        if (admin_ == address(0)) revert ZeroAddress();
        admin = admin_;
        delay = delay_;
    }

    function setAdmin(address admin_) external onlyAdmin {
        if (admin_ == address(0)) revert ZeroAddress();
        admin = admin_;
        emit AdminUpdated(admin_);
    }

    function setDelay(uint256 delay_) external onlyAdmin {
        delay = delay_;
        emit DelayUpdated(delay_);
    }

    function txId(address target, bytes memory data) public pure returns (bytes32) {
        return keccak256(abi.encode(target, data));
    }

    function queue(address target, bytes calldata data) external onlyAdmin returns (bytes32 id) {
        id = txId(target, data);
        if (eta[id] != 0) revert AlreadyQueued();
        uint256 ready = block.timestamp + delay;
        eta[id] = ready;
        emit Queued(id, target, data, ready);
    }

    function cancel(address target, bytes calldata data) external onlyAdmin {
        bytes32 id = txId(target, data);
        if (eta[id] == 0) revert UnknownTx();
        delete eta[id];
        emit Cancelled(id);
    }

    function execute(address target, bytes calldata data) external onlyAdmin {
        bytes32 id = txId(target, data);
        uint256 ready = eta[id];
        if (ready == 0) revert UnknownTx();
        if (block.timestamp < ready) revert NotReady();
        delete eta[id];
        (bool ok, bytes memory err) = target.call(data);
        if (!ok) {
            assembly {
                revert(add(err, 0x20), mload(err))
            }
        }
        emit Executed(id, target, data);
    }
}
