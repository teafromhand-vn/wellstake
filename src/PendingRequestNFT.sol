// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @title PendingRequestNFT
/// @notice Non-transferable claim ticket for Wellstake V1 mint and redeem requests.
///         Token ID equals the Vault request ID. Minted when a request is created and
///         burned on successful claim. The Vault request record remains authoritative.
contract PendingRequestNFT is ERC721 {
    /// @notice The only address authorized to mint and burn tickets.
    address public immutable vault;

    error ZeroAddress();
    error NotVault();
    error NonTransferable();

    modifier onlyVault() {
        if (msg.sender != vault) revert NotVault();
        _;
    }

    constructor(address vault_) ERC721("Wellstake Pending Request", "WSKPR") {
        if (vault_ == address(0)) revert ZeroAddress();
        vault = vault_;
    }

    /// @notice Mint the claim ticket for `requestId` to the request owner.
    function mint(address to, uint256 requestId) external onlyVault {
        _mint(to, requestId);
    }

    /// @notice Burn the claim ticket for `requestId`.
    function burn(uint256 requestId) external onlyVault {
        _burn(requestId);
    }

    /// @dev Only minting (from == 0) and burning (to == 0) are allowed. All transfers revert,
    ///      which makes the collection non-transferable regardless of approvals.
    function _update(address to, uint256 tokenId, address auth)
        internal
        override
        returns (address)
    {
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) revert NonTransferable();
        return super._update(to, tokenId, auth);
    }
}
