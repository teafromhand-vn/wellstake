// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {WellstakeTestBase} from "./WellstakeTestBase.sol";
import {WellstakeVault} from "../src/WellstakeVault.sol";

contract WindDownTest is WellstakeTestBase {
    function test_PAUSE001_managerCanWindDown() public {
        _transition(ONE_USDC); // epoch 2 active
        _windDown(2 * ONE_USDC);

        (uint256 nav,,, bool finalized) = vault.epochs(2);
        assertEq(nav, 2 * ONE_USDC);
        assertTrue(finalized);
        assertEq(vault.currentEpoch(), 2); // no new epoch
        assertTrue(vault.woundDown());
    }

    function test_PAUSE002_nonManagerCannotWindDown() public {
        vm.prank(alice);
        vm.expectRevert(WellstakeVault.OnlyManager.selector);
        vault.pause(ONE_USDC);
        assertFalse(vault.woundDown());
    }

    function test_PAUSE003_windDownIsIrreversible() public {
        _windDown(ONE_USDC);
        // No unpause; second pause reverts.
        vm.prank(manager);
        vm.expectRevert(WellstakeVault.AlreadyWoundDown.selector);
        vault.pause(ONE_USDC);
    }

    function test_PAUSE004_newMintBlocked() public {
        _windDown(ONE_USDC);
        _fundUSDC(alice, 10 * ONE_USDC);
        _approveUSDC(alice, 10 * ONE_USDC);
        vm.prank(alice);
        vm.expectRevert(WellstakeVault.AlreadyWoundDown.selector);
        vault.requestMint(10 * ONE_USDC);
    }

    function test_PAUSE005_newRedeemBlocked() public {
        _giveWSK(alice, 100 * ONE_WSK);
        _windDown(ONE_USDC);
        vm.prank(alice);
        vm.expectRevert(WellstakeVault.AlreadyWoundDown.selector);
        vault.requestRedeem(10 * ONE_WSK);
    }

    function test_PAUSE006_newTransitionBlocked() public {
        _windDown(ONE_USDC);
        vm.prank(manager);
        vm.expectRevert(WellstakeVault.AlreadyWoundDown.selector);
        vault.transitionEpoch(ONE_USDC);
    }

    function test_PAUSE007_existingMintCanStillClaim() public {
        uint256 id = _mint(alice, 100 * ONE_USDC);
        _windDown(ONE_USDC);
        vault.claim(id);
        assertEq(wsk.balanceOf(alice), 100 * ONE_WSK);
    }

    function test_PAUSE008_existingRedeemCanStillClaim() public {
        _giveWSK(alice, 1000 * ONE_WSK);
        uint256 net = 100 * ONE_WSK - (100 * ONE_WSK * FEE_BPS / BPS_DENOMINATOR);
        uint256 id = _requestRedeem(alice, 100 * ONE_WSK);
        _fundLiquid(1000 * ONE_USDC);
        _windDown(ONE_USDC);

        vault.claim(id);
        assertEq(usdc.balanceOf(alice), net);
    }

    function test_PAUSE009_wskTransfersRemainActive() public {
        _giveWSK(alice, 100 * ONE_WSK);
        _windDown(ONE_USDC);

        vm.prank(alice);
        wsk.transfer(bob, 10 * ONE_WSK);
        assertEq(wsk.balanceOf(bob), 10 * ONE_WSK);

        vm.prank(bob);
        wsk.approve(carol, 5 * ONE_WSK);
        vm.prank(carol);
        wsk.transferFrom(bob, carol, 5 * ONE_WSK);
        assertEq(wsk.balanceOf(carol), 5 * ONE_WSK);
    }

    function test_PAUSE010_windDownWithPendingRequests() public {
        uint256 mintId = _mint(alice, 100 * ONE_USDC);
        _giveWSK(bob, 100 * ONE_WSK); // transitions epoch 1->2
        // Mint request above belongs to epoch 1, which is finalized by _giveWSK.
        uint256 redeemId = _requestRedeem(bob, 50 * ONE_WSK); // epoch 2
        _fundLiquid(100 * ONE_USDC);

        _windDown(ONE_USDC); // finalize epoch 2

        vault.claim(mintId);
        vault.claim(redeemId);
        assertEq(wsk.balanceOf(alice), 100 * ONE_WSK);
        (,,,,,, bool claimed) = vault.requests(redeemId);
        assertTrue(claimed);
    }

    function test_PAUSE011_windDownImmediatelyAfterDeployment() public {
        _windDown(INITIAL_NAV);
        (uint256 nav,,, bool finalized) = vault.epochs(1);
        assertEq(nav, INITIAL_NAV);
        assertTrue(finalized);
        assertEq(vault.currentEpoch(), 1); // no subsequent epoch
        assertTrue(vault.woundDown());
    }

    function test_PAUSE_windDownRejectsZeroNavWhenSupplyPositive() public {
        _giveWSK(alice, 100 * ONE_WSK);
        vm.prank(manager);
        vm.expectRevert(WellstakeVault.InvalidNav.selector);
        vault.pause(0);
    }
}
