// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Auth, ReentrancyGuard} from "./lib/Auth.sol";
import {IERC20, SafeERC20} from "./lib/SafeERC20.sol";

/// @title PnlPool
/// @notice House bank + protocol revenue.
/// - `houseBalance` — inventory to cover winner unshields (`cover`)
/// - `feesAccrued` — 0.1% profit fees from closes/decreases
/// - `seizedAccrued` — margin kept on liquidations
/// Admin withdraws each bucket separately. Engine is the only fee/seize payer
/// (`Auth.engine` via `setEngine`).
contract PnlPool is Auth, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ZeroAmount();
    error InsufficientPool();
    error InsufficientFees();
    error InsufficientSeized();

    IERC20 public immutable usdw;

    uint256 public houseBalance;
    uint256 public feesAccrued;
    uint256 public seizedAccrued;

    event Deposited(address indexed from, uint256 amount);
    event Withdrawn(address indexed to, uint256 amount);
    event Covered(address indexed vault, uint256 amount);
    event FeeReceived(uint256 amount);
    event SeizedReceived(uint256 amount);
    event FeesWithdrawn(address indexed to, uint256 amount);
    event SeizedWithdrawn(address indexed to, uint256 amount);

    constructor(address owner_, address usdw_) Auth(owner_) {
        if (usdw_ == address(0)) revert ZeroAddress();
        usdw = IERC20(usdw_);
    }

    function balance() public view returns (uint256) {
        return usdw.balanceOf(address(this));
    }

    function deposit(uint256 amount) external onlyOwner nonReentrant {
        if (amount == 0) revert ZeroAmount();
        usdw.safeTransferFrom(msg.sender, address(this), amount);
        houseBalance += amount;
        emit Deposited(msg.sender, amount);
    }

    function withdraw(address to, uint256 amount) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount > houseBalance) revert InsufficientPool();
        houseBalance -= amount;
        usdw.safeTransfer(to, amount);
        emit Withdrawn(to, amount);
    }

    function withdrawFees(address to, uint256 amount) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount > feesAccrued) revert InsufficientFees();
        feesAccrued -= amount;
        usdw.safeTransfer(to, amount);
        emit FeesWithdrawn(to, amount);
    }

    function withdrawSeized(address to, uint256 amount) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount > seizedAccrued) revert InsufficientSeized();
        seizedAccrued -= amount;
        usdw.safeTransfer(to, amount);
        emit SeizedWithdrawn(to, amount);
    }

    /// @notice Push house USDW into the vault so winner `unshield`s can pay out.
    function cover(address vault, uint256 amount) external onlyOwner nonReentrant {
        if (vault == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount > houseBalance) revert InsufficientPool();
        houseBalance -= amount;
        usdw.safeTransfer(vault, amount);
        emit Covered(vault, amount);
    }

    /// @notice Engine credits 0.1% profit fees (USDW already transferred in).
    function receiveFee(uint256 amount) external onlyEngine nonReentrant {
        if (amount == 0) revert ZeroAmount();
        feesAccrued += amount;
        emit FeeReceived(amount);
    }

    /// @notice Engine credits liquidated margin (USDW already transferred in).
    function receiveSeized(uint256 amount) external onlyEngine nonReentrant {
        if (amount == 0) revert ZeroAmount();
        seizedAccrued += amount;
        emit SeizedReceived(amount);
    }
}
