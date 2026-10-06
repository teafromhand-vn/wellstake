// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {WellstakeTestBase} from "./WellstakeTestBase.sol";
import {WellstakeVault} from "../src/WellstakeVault.sol";

contract AccessControlTest is WellstakeTestBase {
    function test_AUTH001_managerOnlyTransition() public {
        vm.prank(alice);
        vm.expectRevert(WellstakeVault.OnlyManager.selector);
        vault.transitionEpoch(ONE_USDC);

        vm.prank(manager);
        vault.transitionEpoch(ONE_USDC);
        assertEq(vault.currentEpoch(), 2);
    }

    function test_AUTH002_managerOnlyWindDown() public {
        vm.prank(bob);
        vm.expectRevert(WellstakeVault.OnlyManager.selector);
        vault.pause(ONE_USDC);

        vm.prank(manager);
        vault.pause(ONE_USDC);
        assertTrue(vault.woundDown());
    }

    function test_AUTH003_usersCanRequestWithoutManager() public {
        uint256 id = _mint(alice, 10 * ONE_USDC);
        assertEq(id, 1);

        _giveWSK(bob, 100 * ONE_WSK);
        uint256 rid = _requestRedeem(bob, 10 * ONE_WSK);
        assertGt(rid, id);
    }

    function test_AUTH004_permissionlessClaims() public {
        uint256 id = _mint(alice, 100 * ONE_USDC);
        _transition(ONE_USDC);

        vm.prank(makeAddr("random"));
        vault.claim(id);
        assertEq(wsk.balanceOf(alice), 100 * ONE_WSK);
    }
}
