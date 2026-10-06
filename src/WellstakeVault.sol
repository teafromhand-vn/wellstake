// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title WellstakeVault
/// @notice Thin investment pool. It pulls idle USDC from the LiquidWallet, deploys it into
///         off-chain/external strategy via the `vaultWallet` EOA, and returns USDC to the
///         LiquidWallet to fund redemptions. It plays no role in mint/redeem accounting.
contract WellstakeVault is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable usdc;
    address public immutable liquidWallet;
    address public immutable vaultWallet;

    event Pulled(uint256 amount);
    event Returned(uint256 amount);
    event Invested(address indexed to, uint256 amount);

    error ZeroAddress();
    error ZeroAmount();
    error OnlyManager();

    modifier onlyManager() {
        // The vaultWallet EOA is the operational manager of the pool.
        if (msg.sender != vaultWallet) revert OnlyManager();
        _;
    }

    constructor(address usdc_, address liquidWallet_, address vaultWallet_) {
        if (usdc_ == address(0) || liquidWallet_ == address(0) || vaultWallet_ == address(0)) {
            revert ZeroAddress();
        }
        usdc = IERC20(usdc_);
        liquidWallet = liquidWallet_;
        vaultWallet = vaultWallet_;
    }

    /// @notice Pull idle USDC from the LiquidWallet into this pool for investment.
    function pull(uint256 amount) external onlyManager {
        if (amount == 0) revert ZeroAmount();
        ILiquidWallet(liquidWallet).withdraw(address(usdc), amount);
        emit Pulled(amount);
    }

    /// @notice Send USDC held here back to the LiquidWallet to restore redemption liquidity.
    function returnFunds(uint256 amount) external onlyManager {
        if (amount == 0) revert ZeroAmount();
        usdc.safeTransfer(liquidWallet, amount);
        emit Returned(amount);
    }

    /// @notice Forward USDC held here to the operator wallet for external deployment.
    function invest(uint256 amount) external onlyManager {
        if (amount == 0) revert ZeroAmount();
        usdc.safeTransfer(vaultWallet, amount);
        emit Invested(vaultWallet, amount);
    }
}

interface ILiquidWallet {
    function withdraw(address token, uint256 amount) external;
}
