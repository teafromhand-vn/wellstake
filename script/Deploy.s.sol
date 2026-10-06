// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {LiquidWallet} from "../src/LiquidWallet.sol";
import {WellstakeVault} from "../src/WellstakeVault.sol";
import {WellstakeToken} from "../src/WellstakeToken.sol";
import {PendingRequestNFT} from "../src/PendingRequestNFT.sol";

/// @notice Deploys the Wellstake stack: LiquidWallet (mint/redeem, WSK authority, NFT), the thin
///         investment Vault, and links the Vault into the LiquidWallet.
/// @dev Required env: PRIVATE_KEY (deployer), CHAIN_ID, USDC, MANAGER, VAULT_WALLET.
///      MANAGER is also the fee recipient.
contract Deploy is Script {
    function run() external returns (LiquidWallet liquid, WellstakeVault vault) {
        uint256 expectedChainId = vm.envUint("CHAIN_ID");
        if (block.chainid != expectedChainId) revert("Deploy: wrong chain");

        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address usdc = vm.envAddress("USDC");
        address manager = vm.envAddress("MANAGER");
        address vaultWallet = vm.envAddress("VAULT_WALLET");

        vm.startBroadcast(deployerKey);
        liquid = new LiquidWallet(usdc, manager, vaultWallet);
        vault = new WellstakeVault(usdc, address(liquid), vaultWallet);
        vm.stopBroadcast();

        // Link the Vault on the LiquidWallet. Requires the manager to submit this call.
        if (msg.sender == manager) {
            liquid.setVault(address(vault));
        }

        _validate(liquid, vault, usdc, manager, vaultWallet);
        _log(liquid, vault);
    }

    function _validate(
        LiquidWallet liquid,
        WellstakeVault vault,
        address usdc,
        address manager,
        address vaultWallet
    ) internal view {
        WellstakeToken wsk = liquid.wsk();
        PendingRequestNFT nft = liquid.pendingNFT();

        if (address(liquid.usdc()) != usdc) revert("Deploy: usdc mismatch");
        if (liquid.manager() != manager) revert("Deploy: manager mismatch");
        if (liquid.vaultWallet() != vaultWallet) revert("Deploy: vaultWallet mismatch");

        if (address(vault.liquidWallet()) != address(liquid)) {
            revert("Deploy: vault/liquid linkage");
        }
        if (vault.vaultWallet() != vaultWallet) revert("Deploy: vault vaultWallet mismatch");

        if (wsk.authority() != address(liquid)) revert("Deploy: WSK authority");
        if (nft.authority() != address(liquid)) revert("Deploy: NFT authority");
        if (wsk.decimals() != 6) revert("Deploy: WSK decimals");
    }

    function _log(LiquidWallet liquid, WellstakeVault vault) internal view {
        console.log("LiquidWallet:     ", address(liquid));
        console.log("WellstakeVault:   ", address(vault));
        console.log("WellstakeToken:   ", address(liquid.wsk()));
        console.log("PendingRequestNFT:", address(liquid.pendingNFT()));
        console.log("usdc:             ", address(liquid.usdc()));
        console.log("manager (fee):    ", liquid.manager());
        console.log("vaultWallet:      ", liquid.vaultWallet());
        console.log("initial NAV:      ", liquid.totalNav());
    }
}
