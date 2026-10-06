// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title WellstakeToken (WSK)
/// @notice ERC-20 share token for Wellstake. Mint and burn are restricted to the LiquidWallet,
///         which is the sole authority that settles mint and redeem requests.
///         Transfers, transferFrom and approve behave as a normal ERC-20 forever.
contract WellstakeToken is ERC20 {
    /// @notice The only address authorized to mint and burn WSK.
    address public immutable authority;

    error ZeroAddress();
    error NotAuthority();

    modifier onlyAuthority() {
        if (msg.sender != authority) revert NotAuthority();
        _;
    }

    constructor(address authority_, string memory name_, string memory symbol_)
        ERC20(name_, symbol_)
    {
        if (authority_ == address(0)) revert ZeroAddress();
        authority = authority_;
    }

    /// @inheritdoc ERC20
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /// @notice Mint WSK. Callable only by the authority (LiquidWallet).
    function mint(address to, uint256 amount) external onlyAuthority {
        _mint(to, amount);
    }

    /// @notice Burn WSK from an account. Callable only by the authority (LiquidWallet).
    function burn(address from, uint256 amount) external onlyAuthority {
        _burn(from, amount);
    }
}
