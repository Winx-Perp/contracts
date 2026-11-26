// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Auth, ReentrancyGuard} from "../lib/Auth.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {IERC20, SafeERC20} from "../lib/SafeERC20.sol";

/// @title EthUsdwSwap
/// @notice Tester faucet: send Robinhood testnet ETH, receive USDW at $1.
/// Price is ETH/USD in 1e8 (Pyth-style). Admin seeds the contract with USDW
/// from the 1B mint, then withdraws collected ETH.
contract EthUsdwSwap is Auth, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error Paused();
    error ZeroAmount();
    error StalePrice();
    error InvalidPrice();
    error EthTransferFailed();

    IERC20 public immutable usdw;
    IPriceOracle public oracle;
    bytes32 public ethFeedId;
    /// @notice Fallback ETH/USD (1e8) when no oracle is wired. Admin-set for testnet.
    uint256 public ethUsdPrice;
    uint256 public maxPriceAge = 1 hours;
    bool public paused;

    event Swapped(address indexed buyer, uint256 ethIn, uint256 usdwOut);
    event PriceUpdated(uint256 ethUsdPrice);
    event OracleUpdated(address oracle, bytes32 ethFeedId);
    event PausedUpdated(bool paused);
    event EthWithdrawn(address indexed to, uint256 amount);
    event UsdwWithdrawn(address indexed to, uint256 amount);

    constructor(address owner_, address usdw_, uint256 ethUsdPrice_) Auth(owner_) {
        if (usdw_ == address(0) || ethUsdPrice_ == 0) revert ZeroAddress();
        usdw = IERC20(usdw_);
        ethUsdPrice = ethUsdPrice_;
    }

    receive() external payable nonReentrant {
        _swap(msg.sender, msg.value);
    }

    /// @notice ETH → USDW. 1 USDW = $1 (6 decimals), same unit as USDG/USDC.
    function swap() external payable nonReentrant returns (uint256 usdwOut) {
        usdwOut = _swap(msg.sender, msg.value);
    }

    function quote(uint256 weiAmount) public view returns (uint256 usdwOut) {
        usdwOut = (weiAmount * _ethUsd()) / 1e20;
    }

    function setEthUsdPrice(uint256 ethUsdPrice_) external onlyOwner {
        if (ethUsdPrice_ == 0) revert InvalidPrice();
        ethUsdPrice = ethUsdPrice_;
        emit PriceUpdated(ethUsdPrice_);
    }

    function setOracle(address oracle_, bytes32 ethFeedId_) external onlyOwner {
        oracle = IPriceOracle(oracle_);
        ethFeedId = ethFeedId_;
        emit OracleUpdated(oracle_, ethFeedId_);
    }

    function setMaxPriceAge(uint256 maxPriceAge_) external onlyOwner {
        maxPriceAge = maxPriceAge_;
    }

    function setPaused(bool paused_) external onlyOwner {
        paused = paused_;
        emit PausedUpdated(paused_);
    }

    function withdrawEth(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        (bool ok,) = to.call{value: amount}("");
        if (!ok) revert EthTransferFailed();
        emit EthWithdrawn(to, amount);
    }

    function withdrawUsdw(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        usdw.safeTransfer(to, amount);
        emit UsdwWithdrawn(to, amount);
    }

    function _swap(address buyer, uint256 weiAmount) internal returns (uint256 usdwOut) {
        if (paused) revert Paused();
        if (weiAmount == 0) revert ZeroAmount();
        usdwOut = quote(weiAmount);
        if (usdwOut == 0) revert ZeroAmount();
        usdw.safeTransfer(buyer, usdwOut);
        emit Swapped(buyer, weiAmount, usdwOut);
    }

    function _ethUsd() internal view returns (uint256 price) {
        if (address(oracle) == address(0) || ethFeedId == bytes32(0)) {
            price = ethUsdPrice;
        } else {
            uint256 publishTime;
            (price, publishTime) = oracle.getPrice(ethFeedId);
            if (publishTime > block.timestamp || block.timestamp - publishTime > maxPriceAge) {
                revert StalePrice();
            }
        }
        if (price == 0) revert InvalidPrice();
    }
}
