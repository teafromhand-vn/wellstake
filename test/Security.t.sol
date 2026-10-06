// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {WellstakeTestBase} from "./WellstakeTestBase.sol";
import {LiquidWallet} from "../src/LiquidWallet.sol";
import {WellstakeVault} from "../src/WellstakeVault.sol";
import {ReentrantUSDC} from "./mocks/ReentrantUSDC.sol";

contract SecurityTest is WellstakeTestBase {
    function test_onlyManagerSetsNav() public {
        vm.prank(alice);
        vm.expectRevert(LiquidWallet.OnlyManager.selector);
        liquid.setNav(1);
    }

    function test_onlyManagerSetsVault() public {
        // vault already set; only manager can call at all
        vm.prank(alice);
        vm.expectRevert(LiquidWallet.OnlyManager.selector);
        liquid.setVault(address(0xBEEF));
    }

    function test_vaultWithdrawOnlyVault() public {
        uint256 id = _requestMint(alice, 100 * ONE);
        id; // USDC now held by liquid

        // Anyone other than the configured vault cannot withdraw.
        vm.prank(alice);
        vm.expectRevert(LiquidWallet.OnlyVault.selector);
        liquid.withdraw(address(usdc), 1);

        // The vault can withdraw idle USDC.
        vm.prank(address(vault));
        liquid.withdraw(address(usdc), 50 * ONE);
        assertEq(usdc.balanceOf(address(vault)), 50 * ONE);
    }

    function test_vaultOnlyManagerOperations() public {
        vm.prank(alice);
        vm.expectRevert(WellstakeVault.OnlyManager.selector);
        vault.pull(1);

        vm.prank(alice);
        vm.expectRevert(WellstakeVault.OnlyManager.selector);
        vault.returnFunds(1);
    }

    function test_vaultPullAndReturn() public {
        _requestMint(alice, 100 * ONE); // liquid holds 100 USDC

        vm.prank(vaultWallet);
        vault.pull(60 * ONE);
        assertEq(usdc.balanceOf(address(vault)), 60 * ONE);

        vm.prank(vaultWallet);
        vault.returnFunds(40 * ONE);
        assertEq(usdc.balanceOf(address(liquid)), 80 * ONE);
    }

    function test_reentrancyOnMint() public {
        ReentrantUSDC reUsdc = new ReentrantUSDC();
        LiquidWallet reLiquid = new LiquidWallet(address(reUsdc), manager, vaultWallet);

        reUsdc.mint(alice, 100 * ONE);
        vm.prank(alice);
        reUsdc.approve(address(reLiquid), type(uint256).max);

        bytes memory payload = abi.encodeCall(LiquidWallet.requestMint, (1));
        reUsdc.setAttack(address(reLiquid), payload);

        vm.prank(alice);
        vm.expectRevert();
        reLiquid.requestMint(10 * ONE);
    }
}
