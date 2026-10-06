// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {WellstakeTestBase} from "./WellstakeTestBase.sol";
import {WellstakeVault} from "../src/WellstakeVault.sol";

contract DeploymentTest is WellstakeTestBase {
    function test_DEP001_initialTokenConfiguration() public view {
        assertEq(wsk.name(), "Wellstake");
        assertEq(wsk.symbol(), "WSK");
        assertEq(wsk.decimals(), 6);
        assertEq(wsk.vault(), address(vault));
        assertEq(address(vault.usdc()), address(usdc));
        assertEq(vault.manager(), manager);
        assertEq(vault.vaultWallet(), vaultWallet);
        assertEq(vault.liquidWallet(), liquidWallet);
        assertEq(vault.feeWallet(), feeWallet);
    }

    function test_DEP002_epochZeroState() public view {
        (uint256 nav, uint256 startBlock, uint256 endBlock, bool finalized) = vault.epochs(0);
        assertEq(nav, INITIAL_NAV);
        assertEq(startBlock, block.number);
        assertEq(endBlock, block.number);
        assertTrue(finalized);
        assertEq(vault.currentEpoch(), 1);

        // Epoch 1 is open and has no finalized NAV yet.
        (uint256 nav1, uint256 start1, uint256 end1, bool finalized1) = vault.epochs(1);
        assertEq(nav1, 0);
        assertEq(start1, block.number);
        assertEq(end1, 0);
        assertFalse(finalized1);
    }

    function test_DEP003_requestCounterStartsAtOne() public {
        assertEq(vault.nextRequestId(), 1);

        uint256 id = _mint(alice, 10 * ONE_USDC);
        assertEq(id, 1);

        // requestId 0 is never a valid request.
        vm.expectRevert(WellstakeVault.RequestNotFound.selector);
        vault.claim(0);
    }

    function test_DEP_revertsOnZeroConfiguration() public {
        vm.expectRevert(WellstakeVault.ZeroAddress.selector);
        new WellstakeVault(address(0), manager, vaultWallet, liquidWallet, feeWallet);

        vm.expectRevert(WellstakeVault.ZeroAddress.selector);
        new WellstakeVault(address(usdc), address(0), vaultWallet, liquidWallet, feeWallet);

        vm.expectRevert(WellstakeVault.ZeroAddress.selector);
        new WellstakeVault(address(usdc), manager, address(0), liquidWallet, feeWallet);

        vm.expectRevert(WellstakeVault.ZeroAddress.selector);
        new WellstakeVault(address(usdc), manager, vaultWallet, address(0), feeWallet);

        vm.expectRevert(WellstakeVault.ZeroAddress.selector);
        new WellstakeVault(address(usdc), manager, vaultWallet, liquidWallet, address(0));
    }
}
