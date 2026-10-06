// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {LiquidWallet} from "../src/LiquidWallet.sol";
import {WellstakeVault} from "../src/WellstakeVault.sol";
import {WellstakeToken} from "../src/WellstakeToken.sol";
import {PendingRequestNFT} from "../src/PendingRequestNFT.sol";
import {TestQuoteToken} from "../src/mocks/TestQuoteToken.sol";

/// @notice Deploys a testQuoteToken (QT) quote asset, then a Wellstake stack settling in QT:
///         LiquidWallet (deploys qtWellstake/qtWSK + PendingRequestNFT), the investment Vault,
///         seeds the LiquidWallet and the deployer with QT, and links the Vault.
/// @dev Required env: PRIVATE_KEY (deployer), CHAIN_ID, MANAGER, VAULT_WALLET.
///      MANAGER_PRIVATE_KEY optional (used to link the Vault when manager != deployer).
contract DeployWithQuoteToken is Script {
    function run()
        external
        returns (TestQuoteToken quote, LiquidWallet liquid, WellstakeVault vault)
    {
        uint256 expectedChainId = vm.envUint("CHAIN_ID");
        if (block.chainid != expectedChainId) revert("Deploy: wrong chain");

        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address manager = vm.envAddress("MANAGER");
        address vaultWallet = vm.envAddress("VAULT_WALLET");

        vm.startBroadcast(deployerKey);
        quote = new TestQuoteToken();
        liquid = new LiquidWallet(address(quote), manager, vaultWallet, "qtWellstake", "qtWSK");
        vault = new WellstakeVault(address(quote), address(liquid), vaultWallet);

        // Seed the LiquidWallet with QT for redemptions and the deployer for mint testing.
        quote.mint(address(liquid), 1_000_000 * 1e6);
        quote.mint(vm.addr(deployerKey), 1_000_000 * 1e6);
        vm.stopBroadcast();

        uint256 managerKey = vm.envOr("MANAGER_PRIVATE_KEY", deployerKey);
        vm.startBroadcast(managerKey);
        liquid.setVault(address(vault));
        vm.stopBroadcast();

        _validate(quote, liquid, vault);
        _log(quote, liquid, vault);
    }

    function _validate(TestQuoteToken quote, LiquidWallet liquid, WellstakeVault vault)
        internal
        view
    {
        WellstakeToken wsk = liquid.wsk();
        PendingRequestNFT nft = liquid.pendingNFT();

        if (address(liquid.usdc()) != address(quote)) revert("Deploy: quote mismatch");
        if (address(vault.liquidWallet()) != address(liquid)) revert("Deploy: vault/liquid link");
        if (wsk.authority() != address(liquid)) revert("Deploy: WSK authority");
        if (nft.authority() != address(liquid)) revert("Deploy: NFT authority");
        if (liquid.vault() != address(vault)) revert("Deploy: vault not linked");
        if (quote.decimals() != 6) revert("Deploy: quote decimals");
    }

    function _log(TestQuoteToken quote, LiquidWallet liquid, WellstakeVault vault) internal view {
        console.log("testQuoteToken (QT):", address(quote));
        console.log("LiquidWallet:       ", address(liquid));
        console.log("WellstakeVault:     ", address(vault));
        console.log("WellstakeToken:     ", address(liquid.wsk()));
        console.log("PendingRequestNFT:  ", address(liquid.pendingNFT()));
        console.log("WSK name/symbol:     qtWellstake / qtWSK");
        console.log("initial NAV:        ", liquid.totalNav());
    }
}
