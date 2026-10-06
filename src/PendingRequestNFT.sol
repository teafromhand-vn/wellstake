// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @title PendingRequestNFT
/// @notice Transferable claim ticket for Wellstake mint and redeem requests. Token ID equals the
///         Vault request ID. Minted when a request is created and burned by the LiquidWallet on
///         successful claim. Whoever holds the ticket at claim time receives the settlement.
contract PendingRequestNFT is ERC721 {
    /// @notice The only address authorized to mint and burn tickets.
    address public immutable authority;

    error ZeroAddress();
    error NotAuthority();

    modifier onlyAuthority() {
        if (msg.sender != authority) revert NotAuthority();
        _;
    }

    constructor(address authority_) ERC721("Wellstake Pending Request", "WSKPR") {
        if (authority_ == address(0)) revert ZeroAddress();
        authority = authority_;
    }

    /// @notice Mint the claim ticket for `requestId` to the request owner.
    function mint(address to, uint256 requestId) external onlyAuthority {
        _mint(to, requestId);
    }

    /// @notice Burn the claim ticket for `requestId`.
    function burn(uint256 requestId) external onlyAuthority {
        _burn(requestId);
    }
}
