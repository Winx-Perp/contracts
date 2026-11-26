// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

abstract contract Auth {
    error NotOwner();
    error NotEngine();
    error NotKeeper();
    error ZeroAddress();
    error NotPendingOwner();

    address public owner;
    address public pendingOwner;
    address public engine;
    mapping(address => bool) public keepers;

    event OwnerTransferStarted(address indexed pendingOwner);
    event OwnerUpdated(address indexed owner);
    event EngineUpdated(address indexed engine);
    event KeeperUpdated(address indexed keeper, bool allowed);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyEngine() {
        if (msg.sender != engine) revert NotEngine();
        _;
    }

    modifier onlyOwnerOrKeeper() {
        if (msg.sender != owner && !keepers[msg.sender]) revert NotKeeper();
        _;
    }

    constructor(address owner_) {
        if (owner_ == address(0)) revert ZeroAddress();
        owner = owner_;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        pendingOwner = newOwner;
        emit OwnerTransferStarted(newOwner);
    }

    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert NotPendingOwner();
        owner = pendingOwner;
        pendingOwner = address(0);
        emit OwnerUpdated(owner);
    }

    function setEngine(address engine_) external onlyOwner {
        if (engine_ == address(0)) revert ZeroAddress();
        engine = engine_;
        emit EngineUpdated(engine_);
    }

    function setKeeper(address keeper, bool allowed) external onlyOwner {
        keepers[keeper] = allowed;
        emit KeeperUpdated(keeper, allowed);
    }
}

abstract contract ReentrancyGuard {
    error Reentrant();

    uint256 private _locked = 1;

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrant();
        _locked = 2;
        _;
        _locked = 1;
    }
}
