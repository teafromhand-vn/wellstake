// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {LiquidWallet} from "../src/LiquidWallet.sol";
import {WellstakeVault} from "../src/WellstakeVault.sol";
import {WellstakeToken} from "../src/WellstakeToken.sol";
import {PendingRequestNFT} from "../src/PendingRequestNFT.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";

/// @notice Deploys a self-contained Wellstake stack to a testnet: MockUSDC, LiquidWallet
///         (which deploys WSK + PendingRequestNFT), the investment Vault, seeds the LiquidWallet
///         with test USDC, links the Vault, and funds the deployer for mint testing.
/// @dev Required env: PRIVATE_KEY (deployer), MANAGER, VAULT_WALLET.
///      MANAGER is also the fee recipient. MANAGER_PRIVATE_KEY is used to set the Vault link
///      when the manager differs from the deployer.
contract DeployTestnet is Script {
    uint256 internal constant OP_SEPOLIA_CHAIN_ID = 11155420;

    function run() external returns (LiquidWallet liquid, WellstakeVault vault, MockUSDC usdc) {
        if (block.chainid != OP_SEPOLIA_CHAIN_ID) revert("DeployTestnet: not OP Sepolia");

        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address manager = vm.envAddress("MANAGER");
        address vaultWallet = vm.envAddress("VAULT_WALLET");

        vm.startBroadcast(deployerKey);
        usdc = new MockUSDC();
        liquid = new LiquidWallet(address(usdc), manager, vaultWallet);
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
        console.log("vaultWallet:     ", liquid.vaultWallet());
        console.log("initial NAV:     ", liquid.totalNav());
    }
}
