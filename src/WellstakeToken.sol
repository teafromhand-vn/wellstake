// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title WellstakeToken (WSK)
/// @notice ERC-20 share token for Wellstake V1. Mint and burn are restricted to the Vault.
///         Transfers, transferFrom and approve behave as a normal ERC-20 forever, including
///         after the Vault has been wound down.
contract WellstakeToken is ERC20 {
    /// @notice The only address authorized to mint and burn WSK.
    address public immutable vault;

    error ZeroAddress();
    error NotVault();

    modifier onlyVault() {
        if (msg.sender != vault) revert NotVault();
        _;
    }

    constructor(address vault_) ERC20("Wellstake", "WSK") {
        if (vault_ == address(0)) revert ZeroAddress();
        vault = vault_;
    }

    /// @inheritdoc ERC20
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /// @notice Mint WSK. Callable only by the Vault.
    function mint(address to, uint256 amount) external onlyVault {
        _mint(to, amount);
    }

    /// @notice Burn WSK from an account. Callable only by the Vault.
    function burn(address from, uint256 amount) external onlyVault {
        _burn(from, amount);
    }
}
