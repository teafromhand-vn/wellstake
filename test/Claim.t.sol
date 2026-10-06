// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {WellstakeTestBase} from "./WellstakeTestBase.sol";
import {WellstakeVault} from "../src/WellstakeVault.sol";

contract ClaimTest is WellstakeTestBase {
    function test_CLAIM001_claimExactlyOnce() public {
        uint256 id = _mint(alice, 100 * ONE_USDC);
        _transition(ONE_USDC);

        vault.claim(id);
        vm.expectRevert(WellstakeVault.RequestAlreadyClaimed.selector);
        vault.claim(id);
    }

    function test_CLAIM002_requestRemainsQueryableAfterClaim() public {
        uint256 id = _mint(alice, 100 * ONE_USDC);
        _transition(ONE_USDC);
        vault.claim(id);

        (WellstakeVault.RequestType t, address owner, uint256 epoch, uint256 amt,,, bool claimed) =
            vault.requests(id);
        assertEq(uint256(t), uint256(WellstakeVault.RequestType.MINT));
        assertEq(owner, alice);
        assertEq(epoch, 1);
        assertEq(amt, 100 * ONE_USDC);
        assertTrue(claimed);
    }

    function test_CLAIM003_ownerCannotBeChanged() public {
        uint256 id = _mint(alice, 100 * ONE_USDC);
        (, address owner,,,,,) = vault.requests(id);
        assertEq(owner, alice);

        // No transfer/cancel operation exists; NFT transfer is blocked.
        vm.prank(alice);
        vm.expectRevert();
        nft.transferFrom(alice, bob, id);

        (, owner,,,,,) = vault.requests(id);
        assertEq(owner, alice);
    }

    function test_CLAIM004_callerIsNotBeneficiary() public {
        uint256 id = _mint(alice, 100 * ONE_USDC);
        _transition(ONE_USDC);

        vm.prank(carol);
        vault.claim(id);

        assertEq(wsk.balanceOf(alice), 100 * ONE_WSK);
        assertEq(wsk.balanceOf(carol), 0);
    }

    function test_CLAIM_requestIdZeroRejected() public {
        vm.expectRevert(WellstakeVault.RequestNotFound.selector);
        vault.claim(0);
    }

    function test_CLAIM_unknownRequestRejected() public {
        vm.expectRevert(WellstakeVault.RequestNotFound.selector);
        vault.claim(999);
    }
}
