// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {WellstakeVault} from "../src/WellstakeVault.sol";
import {WellstakeToken} from "../src/WellstakeToken.sol";
import {PendingRequestNFT} from "../src/PendingRequestNFT.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";

/// @notice Deploys a self-contained Wellstake V1 stack to OP Sepolia (chain 11155420):
///         a 6-decimal MockUSDC, the Vault (which deploys WSK + PendingRequestNFT),
///         seeds the liquid wallet with test USDC and grants the Vault an allowance.
/// @dev Required env: PRIVATE_KEY (deployer), MANAGER, VAULT_WALLET, LIQUID_WALLET,
///      FEE_WALLET, LIQUID_PRIVATE_KEY (to fund/approve the liquid wallet).
contract DeployTestnet is Script {
    uint256 internal constant OP_SEPOLIA_CHAIN_ID = 11155420;

    function run() external returns (WellstakeVault vault, MockUSDC usdc) {
        if (block.chainid != OP_SEPOLIA_CHAIN_ID) revert("DeployTestnet: not OP Sepolia");

        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        uint256 liquidKey = vm.envUint("LIQUID_PRIVATE_KEY");
        address manager = vm.envAddress("MANAGER");
        address vaultWallet = vm.envAddress("VAULT_WALLET");
        address liquidWallet = vm.envAddress("LIQUID_WALLET");
        address feeWallet = vm.envAddress("FEE_WALLET");

        // 1. Deploy the stack from the deployer account.
        vm.startBroadcast(deployerKey);
        usdc = new MockUSDC();
        vault = new WellstakeVault(address(usdc), manager, vaultWallet, liquidWallet, feeWallet);
        // Fund the liquid wallet with a little gas so it can approve the Vault.
        payable(liquidWallet).transfer(0.002 ether);
        vm.stopBroadcast();

        // 2. Seed the liquid wallet with test USDC and approve the Vault to pull it.
        vm.startBroadcast(liquidKey);
        usdc.mint(liquidWallet, 1_000_000 * 1e6);
        usdc.approve(address(vault), type(uint256).max);
        vm.stopBroadcast();

        // 3. Fund the deployer with test USDC so mint requests can be exercised.
        vm.startBroadcast(deployerKey);
        usdc.mint(vm.addr(deployerKey), 1_000_000 * 1e6);
        vm.stopBroadcast();

        _log(vault, usdc);
    }

    function _log(WellstakeVault vault, MockUSDC usdc) internal view {
        WellstakeToken wsk = vault.wsk();
        PendingRequestNFT nft = vault.pendingNFT();

        console.log("MockUSDC:        ", address(usdc));
        console.log("WellstakeVault:  ", address(vault));
        console.log("WellstakeToken:  ", address(wsk));
        console.log("PendingRequestNFT:", address(nft));
        console.log("manager:         ", vault.manager());
        console.log("vaultWallet:     ", vault.vaultWallet());
        console.log("liquidWallet:    ", vault.liquidWallet());
        console.log("feeWallet:       ", vault.feeWallet());
        console.log("initial NAV:     ", vault.lastNavPerToken());
    }
}
