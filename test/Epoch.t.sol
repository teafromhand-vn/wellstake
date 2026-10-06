// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {WellstakeTestBase} from "./WellstakeTestBase.sol";
import {WellstakeVault} from "../src/WellstakeVault.sol";

contract EpochTest is WellstakeTestBase {
    function test_EPOCH001_transitionActiveEpoch() public {
        uint256 finalizeBlock = block.number + 5;
        vm.roll(finalizeBlock);

        _transition(ONE_USDC);

        (uint256 nav, uint256 start, uint256 end, bool finalized) = vault.epochs(1);
        assertEq(nav, ONE_USDC);
        assertEq(start, block.number - 5);
        assertEq(end, finalizeBlock);
        assertTrue(finalized);

        assertEq(vault.currentEpoch(), 2);
        (uint256 nav2, uint256 start2, uint256 end2, bool finalized2) = vault.epochs(2);
        assertEq(nav2, 0);
        assertEq(start2, finalizeBlock);
        assertEq(end2, 0);
        assertFalse(finalized2);
    }

    function test_EPOCH002_transitionWithPendingMint() public {
        uint256 id = _mint(alice, 100 * ONE_USDC);

        _transition(ONE_USDC);

        (,,, bool finalized) = vault.epochs(1);
        assertTrue(finalized);
        (WellstakeVault.RequestType t, address owner, uint256 epoch,,,, bool claimed) =
            vault.requests(id);
        assertEq(uint256(t), uint256(WellstakeVault.RequestType.MINT));
        assertEq(owner, alice);
        assertEq(epoch, 1);
        assertFalse(claimed);

        // Claim uses the locked Epoch 1 NAV.
        vault.claim(id);
        assertEq(wsk.balanceOf(alice), 100 * ONE_WSK);
    }

    function test_EPOCH003_transitionWithPendingRedeem() public {
        _giveWSK(alice, 100 * ONE_WSK);
        uint256 id = _requestRedeem(alice, 100 * ONE_WSK);

        _transition(ONE_USDC);
        (,, uint256 epoch,,,, bool claimed) = vault.requests(id);
        assertEq(epoch, 2);
        assertFalse(claimed);
    }

    function test_EPOCH004_transitionWithNoRequestsAndConsecutiveEmptyEpochs() public {
        _transition(ONE_USDC);
        _transition(2 * ONE_USDC);
        _transition(3 * ONE_USDC);
        assertEq(vault.currentEpoch(), 4);
        assertTrue(_isFinalized(1));
        assertTrue(_isFinalized(2));
        assertTrue(_isFinalized(3));
    }

    function test_EPOCH005_sameNavTransition() public {
        _transition(INITIAL_NAV);
        (uint256 nav,,, bool finalized) = vault.epochs(1);
        assertEq(nav, INITIAL_NAV);
        assertTrue(finalized);
    }

    function test_EPOCH006_navCanIncrease() public {
        _giveWSK(alice, 100 * ONE_WSK);
        _transition(2 * ONE_USDC);
        (uint256 nav,,,) = vault.epochs(2);
        assertEq(nav, 2 * ONE_USDC);
    }

    function test_EPOCH007_navCanDecrease() public {
        _giveWSK(alice, 100 * ONE_WSK);
        _transition(ONE_USDC / 2);
        (uint256 nav,,,) = vault.epochs(2);
        assertEq(nav, ONE_USDC / 2);
    }

    function test_EPOCH008_nonManagerCannotTransition() public {
        vm.prank(alice);
        vm.expectRevert(WellstakeVault.OnlyManager.selector);
        vault.transitionEpoch(ONE_USDC);
        assertEq(vault.currentEpoch(), 1);
    }

    function test_EPOCH009_finalizedNavImmutable() public {
        _transition(ONE_USDC);
        (uint256 before,,,) = vault.epochs(1);

        // Further transitions only affect newer epochs.
        _transition(5 * ONE_USDC);
        (uint256 after_,,,) = vault.epochs(1);
        assertEq(after_, before);
        assertEq(after_, ONE_USDC);
    }

    function test_EPOCH010_requestAfterTransitionBelongsToNewEpoch() public {
        _transition(ONE_USDC);
        uint256 id = _mint(alice, 10 * ONE_USDC);
        (,, uint256 epoch,,,,) = vault.requests(id);
        assertEq(epoch, 2);
    }

    function test_EPOCH011_requestBeforeTransitionBelongsToOldEpoch() public {
        uint256 id = _mint(alice, 10 * ONE_USDC);
        _transition(ONE_USDC);
        (,, uint256 epoch,,,,) = vault.requests(id);
        assertEq(epoch, 1);
    }

    function test_EPOCH012_transactionOrderingDeterminesBoundary() public {
        // Request mined before the transition -> epoch 1.
        uint256 before = _mint(alice, 10 * ONE_USDC);
        _transition(ONE_USDC);
        // Request mined after the transition -> epoch 2.
        uint256 after_ = _mint(bob, 10 * ONE_USDC);

        (,, uint256 e1,,,,) = vault.requests(before);
        (,, uint256 e2,,,,) = vault.requests(after_);
        assertEq(e1, 1);
        assertEq(e2, 2);
    }

    function _isFinalized(uint256 epoch) internal view returns (bool finalized) {
        (,,, finalized) = vault.epochs(epoch);
    }
}
