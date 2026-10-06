// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {WellstakeTestBase} from "./WellstakeTestBase.sol";
import {WellstakeVault} from "../src/WellstakeVault.sol";

contract SupplyNavEdgeTest is WellstakeTestBase {
    function test_EDGE001_zeroNavInvalidWhenSupplyPositive() public {
        _giveWSK(alice, 100 * ONE_WSK);
        assertGt(wsk.totalSupply(), 0);

        vm.prank(manager);
        vm.expectRevert(WellstakeVault.InvalidNav.selector);
        vault.transitionEpoch(0);
    }

    function test_EDGE002_zeroSupplyAllowsZeroNavAndFutureMinting() public {
        // No supply yet.
        assertEq(wsk.totalSupply(), 0);
        _transition(0); // allowed
        (uint256 nav,,, bool finalized) = vault.epochs(1);
        assertEq(nav, 0);
        assertTrue(finalized);

        // Future minting remains possible once a positive NAV is set.
        _transition(ONE_USDC);
        uint256 id = _mint(alice, 100 * ONE_USDC);
        (,, uint256 epoch,,,,) = vault.requests(id);
        assertEq(epoch, 3);

        _transition(ONE_USDC); // finalize epoch 3
        vault.claim(id);
        assertEq(wsk.balanceOf(alice), 100 * ONE_WSK);
    }

    function test_EDGE003_previousReferenceRateRetained() public {
        // Finalize with a NAV, then burn all supply (via redeem) to reach zero supply.
        _giveWSK(alice, 100 * ONE_WSK); // epoch1 finalized at 1e6
        assertEq(vault.lastNavPerToken(), ONE_USDC);

        _transition(3 * ONE_USDC);
        assertEq(vault.lastNavPerToken(), 3 * ONE_USDC);
    }

    function test_EDGE004_emptyEpochsAfterSupplyZero() public {
        _transition(0);
        _transition(0);
        _transition(5 * ONE_USDC);
        assertEq(vault.currentEpoch(), 4);
    }

    function test_EDGE005_dustAssetsDoNotBlockTransition() public {
        // Direct-donated USDC dust must not block transitions.
        _fundUSDC(alice, 1);
        vm.prank(alice);
        usdc.transfer(address(vault), 1);

        _transition(ONE_USDC);
        assertTrue(_finalized(1));
    }

    function _finalized(uint256 epoch) internal view returns (bool f) {
        (,,, f) = vault.epochs(epoch);
    }
}
