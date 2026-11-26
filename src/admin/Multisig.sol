// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice N-of-M executor. Set as Timelock admin or as Vault/Engine owner.
contract Multisig {
    error NotSigner();
    error AlreadyApproved();
    error Threshold();
    error ExecFailed();
    error DupSigner();
    error ZeroAddress();

    address[] public signers;
    mapping(address => bool) public isSigner;
    uint256 public threshold;
    mapping(bytes32 => uint256) public approvalCount;
    mapping(bytes32 => mapping(address => bool)) public approved;
    mapping(bytes32 => bool) public executed;

    event Submitted(bytes32 indexed id, address target, bytes data);
    event Approved(bytes32 indexed id, address signer, uint256 count);
    event Executed(bytes32 indexed id);

    constructor(address[] memory signers_, uint256 threshold_) {
        uint256 n = signers_.length;
        if (n == 0 || threshold_ == 0 || threshold_ > n) revert Threshold();
        for (uint256 i; i < n; ++i) {
            address s = signers_[i];
            if (s == address(0)) revert ZeroAddress();
            if (isSigner[s]) revert DupSigner();
            isSigner[s] = true;
            signers.push(s);
        }
        threshold = threshold_;
    }

    function idOf(address target, bytes memory data) public pure returns (bytes32) {
        return keccak256(abi.encode(target, data));
    }

    function submit(address target, bytes calldata data) external returns (bytes32 id) {
        if (!isSigner[msg.sender]) revert NotSigner();
        id = idOf(target, data);
        emit Submitted(id, target, data);
        _approve(id);
    }

    function confirm(bytes32 id) external {
        if (!isSigner[msg.sender]) revert NotSigner();
        _approve(id);
    }

    function execute(address target, bytes calldata data) external {
        bytes32 id = idOf(target, data);
        if (approvalCount[id] < threshold) revert Threshold();
        if (executed[id]) revert AlreadyApproved();
        executed[id] = true;
        (bool ok, bytes memory err) = target.call(data);
        if (!ok) {
            assembly {
                revert(add(err, 0x20), mload(err))
            }
        }
        emit Executed(id);
        err;
    }

    function _approve(bytes32 id) internal {
        if (approved[id][msg.sender]) revert AlreadyApproved();
        approved[id][msg.sender] = true;
        uint256 count = approvalCount[id] + 1;
        approvalCount[id] = count;
        emit Approved(id, msg.sender, count);
    }
}
