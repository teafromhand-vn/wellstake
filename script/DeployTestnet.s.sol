// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {LiquidWallet} from "../src/LiquidWallet.sol";
import {WellstakeVault} from "../src/WellstakeVault.sol";
import {WellstakeToken} from "../src/WellstakeToken.sol";
import {PendingRequestNFT} from "../src/PendingRequestNFT.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";

/// @notice Deploys a self-contained Wellstake stack to a testnet using a local MockUSDC:
///         MockUSDC, LiquidWallet (deploys tWSK + PendingRequestNFT), the investment Vault,
///         seeds the LiquidWallet with test USDC, links the Vault, and funds the deployer.
/// @dev Required env: PRIVATE_KEY (deployer), CHAIN_ID, MANAGER, VAULT_WALLET.
///      Optional: TOKEN_NAME (default "testWellstake"), TOKEN_SYMBOL (default "tWSK"),
///      MANAGER_PRIVATE_KEY (to link the Vault when manager != deployer).
contract DeployTestnet is Script {
    function run() external returns (LiquidWallet liquid, WellstakeVault vault, MockUSDC usdc) {
        uint256 expectedChainId = vm.envUint("CHAIN_ID");
        if (block.chainid != expectedChainId) revert("DeployTestnet: wrong chain");

        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address manager = vm.envAddress("MANAGER");
        address vaultWallet = vm.envAddress("VAULT_WALLET");
        string memory tokenName = vm.envOr("TOKEN_NAME", string("testWellstake"));
        string memory tokenSymbol = vm.envOr("TOKEN_SYMBOL", string("tWSK"));

        vm.startBroadcast(deployerKey);
        usdc = new MockUSDC();
        liquid = new LiquidWallet(address(usdc), manager, vaultWallet, tokenName, tokenSymbol);
        vault = new WellstakeVault(address(usdc), address(liquid), vaultWallet);

        // Seed the LiquidWallet with test USDC and fund the deployer with test USDC.
        usdc.mint(address(liquid), 1_000_000 * 1e6);
        usdc.mint(vm.addr(deployerKey), 1_000_000 * 1e6);
        vm.stopBroadcast();

        // Link the Vault (requires manager authority).
        uint256 managerKey = vm.envOr("MANAGER_PRIVATE_KEY", deployerKey);
        vm.startBroadcast(managerKey);
        liquid.setVault(address(vault));
        vm.stopBroadcast();

        _log(liquid, vault, usdc);
    }

    function _log(LiquidWallet liquid, WellstakeVault vault, MockUSDC usdc) internal view {
        WellstakeToken wsk = liquid.wsk();
        PendingRequestNFT nft = liquid.pendingNFT();

        console.log("MockUSDC:        ", address(usdc));
        console.log("LiquidWallet:    ", address(liquid));
        console.log("WellstakeVault:  ", address(vault));
        console.log("WellstakeToken:  ", address(wsk));
        console.log("PendingRequestNFT:", address(nft));
        console.log("manager (fee):   ", liquid.manager());
        console.log("vaultWallet:     ", vault.vaultWallet());
        console.log("initial NAV:     ", liquid.totalNav());
    }
}
