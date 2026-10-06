// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {WellstakeTestBase} from "./WellstakeTestBase.sol";
import {LiquidWallet} from "../src/LiquidWallet.sol";
import {WellstakeVault} from "../src/WellstakeVault.sol";

contract DeploymentTest is WellstakeTestBase {
    function test_tokenConfig() public view {
        assertEq(wsk.name(), "Wellstake");
        assertEq(wsk.symbol(), "WSK");
        assertEq(wsk.decimals(), 6);
        assertEq(wsk.authority(), address(liquid));
    }

    function test_nftConfig() public view {
        assertEq(nft.name(), "Wellstake Pending Request");
        assertEq(nft.symbol(), "WSKPR");
        assertEq(nft.authority(), address(liquid));
    }

    function test_liquidConfig() public view {
        assertEq(address(liquid.usdc()), address(usdc));
        assertEq(liquid.manager(), manager);
        assertEq(liquid.vaultWallet(), vaultWallet);
        assertEq(liquid.vault(), address(vault));
        assertEq(liquid.totalNav(), INITIAL_NAV);
        assertEq(liquid.rate(), INITIAL_NAV);
    }

    function test_vaultConfig() public view {
        assertEq(address(vault.usdc()), address(usdc));
        assertEq(vault.liquidWallet(), address(liquid));
        assertEq(vault.vaultWallet(), vaultWallet);
    }

    function test_requestCounterStartsAtOne() public {
        assertEq(liquid.nextRequestId(), 1);
        uint256 id = _requestMint(alice, 10 * ONE);
        assertEq(id, 1);
    }

    function test_setVaultOnlyOnce() public {
        vm.prank(manager);
        vm.expectRevert(LiquidWallet.VaultAlreadySet.selector);
        liquid.setVault(address(0xBEEF));
    }

    function test_revertsOnZeroConfig() public {
        vm.expectRevert(LiquidWallet.ZeroAddress.selector);
        new LiquidWallet(address(0), manager, vaultWallet, "W", "W");

        vm.expectRevert(LiquidWallet.ZeroAddress.selector);
        new LiquidWallet(address(usdc), address(0), vaultWallet, "W", "W");

        vm.expectRevert(LiquidWallet.ZeroAddress.selector);
        new LiquidWallet(address(usdc), manager, address(0), "W", "W");

        vm.expectRevert(WellstakeVault.ZeroAddress.selector);
        new WellstakeVault(address(0), address(liquid), vaultWallet);
    }
}
