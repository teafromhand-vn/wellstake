// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";

import {WellstakeVault} from "../src/WellstakeVault.sol";
import {WellstakeToken} from "../src/WellstakeToken.sol";
import {PendingRequestNFT} from "../src/PendingRequestNFT.sol";

/// @notice Deploys Wellstake V1 and validates the fixed deployment configuration.
/// @dev Required environment variables:
///      MANAGER, VAULT_WALLET, LIQUID_WALLET, FEE_WALLET.
///      Optional: USDC (must equal the fixed Optimism USDC address when set).
contract Deploy is Script {
    /// @dev Native USDC on Optimism.
    address internal constant OP_USDC = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
    uint256 internal constant OP_CHAIN_ID = 10;
    uint256 internal constant INITIAL_NAV = 38_462;

    function run() external returns (WellstakeVault vault) {
        if (block.chainid != OP_CHAIN_ID) revert("Deploy: wrong chain (expected Optimism)");

        address usdc = vm.envOr("USDC", OP_USDC);
        if (usdc != OP_USDC) revert("Deploy: USDC must be Optimism USDC");

        address manager = vm.envAddress("MANAGER");
        address vaultWallet = vm.envAddress("VAULT_WALLET");
        address liquidWallet = vm.envAddress("LIQUID_WALLET");
        address feeWallet = vm.envAddress("FEE_WALLET");

        vm.startBroadcast();
        vault = new WellstakeVault(usdc, manager, vaultWallet, liquidWallet, feeWallet);
        vm.stopBroadcast();

        _validate(vault, usdc, manager, vaultWallet, liquidWallet, feeWallet);
    }

    function _validate(
        WellstakeVault vault,
        address usdc,
        address manager,
        address vaultWallet,
        address liquidWallet,
        address feeWallet
    ) internal view {
        WellstakeToken wsk = vault.wsk();
        PendingRequestNFT nft = vault.pendingNFT();

        if (address(vault.usdc()) != usdc) revert("Deploy: usdc mismatch");
        if (vault.manager() != manager) revert("Deploy: manager mismatch");
        if (vault.vaultWallet() != vaultWallet) revert("Deploy: vaultWallet mismatch");
        if (vault.liquidWallet() != liquidWallet) revert("Deploy: liquidWallet mismatch");
        if (vault.feeWallet() != feeWallet) revert("Deploy: feeWallet mismatch");

        if (wsk.vault() != address(vault)) revert("Deploy: token/vault linkage");
        if (nft.vault() != address(vault)) revert("Deploy: nft/vault linkage");
        if (wsk.decimals() != 6) revert("Deploy: WSK decimals");

        // Epoch 0 finalized at deployment block; Epoch 1 active.
        (uint256 nav0, uint256 start0, uint256 end0, bool fin0) = vault.epochs(0);
        if (nav0 != INITIAL_NAV || start0 != block.number || end0 != block.number || !fin0) {
            revert("Deploy: bad epoch 0");
        }
        if (vault.currentEpoch() != 1) revert("Deploy: active epoch != 1");
        if (vault.lastNavPerToken() != INITIAL_NAV) revert("Deploy: last nav");
    }
}
