// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {WellstakeTestBase} from "./WellstakeTestBase.sol";
import {WellstakeVault} from "../src/WellstakeVault.sol";

contract BatchClaimTest is WellstakeTestBase {
    function test_BATCH001_multipleSuccessfulClaims() public {
        uint256 a = _mint(alice, 10 * ONE_USDC);
        uint256 b = _mint(bob, 20 * ONE_USDC);
        uint256 c = _mint(carol, 30 * ONE_USDC);
        _transition(ONE_USDC);

        uint256[] memory ids = new uint256[](3);
        ids[0] = a;
        ids[1] = b;
        ids[2] = c;
        vault.claimMany(ids);

        assertEq(wsk.balanceOf(alice), 10 * ONE_WSK);
        assertEq(wsk.balanceOf(bob), 20 * ONE_WSK);
        assertEq(wsk.balanceOf(carol), 30 * ONE_WSK);
    }

    function test_BATCH002_mixedMintAndRedeem() public {
        // Epoch 1: alice redeems; we need WSK first via a prior helper.
        _giveWSK(alice, 100 * ONE_WSK); // finalizes epoch1, opens epoch2

        uint256 mintId = _mint(bob, 50 * ONE_USDC); // epoch 2
        uint256 redeemId = _requestRedeem(alice, 50 * ONE_WSK); // epoch 2
        _transition(ONE_USDC); // finalize epoch 2
        _fundLiquid(100 * ONE_USDC);

        uint256[] memory ids = new uint256[](2);
        ids[0] = mintId;
        ids[1] = redeemId;
        vault.claimMany(ids);

        assertEq(wsk.balanceOf(bob), 50 * ONE_WSK);
        (,,,,,, bool claimed) = vault.requests(redeemId);
        assertTrue(claimed);
    }

    function test_BATCH003_callerOrderPreserved() public {
        uint256 a = _mint(alice, 10 * ONE_USDC);
        uint256 b = _mint(bob, 20 * ONE_USDC);
        uint256 c = _mint(carol, 30 * ONE_USDC);
        _transition(ONE_USDC);

        // Record mint order via expectEmit sequence: 3,1,2.
        vm.expectEmit(true, true, false, false);
        emit WellstakeVault.MintClaimed(3, carol, 30 * ONE_WSK);
        vm.expectEmit(true, true, false, false);
        emit WellstakeVault.MintClaimed(1, alice, 10 * ONE_WSK);
        vm.expectEmit(true, true, false, false);
        emit WellstakeVault.MintClaimed(2, bob, 20 * ONE_WSK);

        uint256[] memory ids = new uint256[](3);
        ids[0] = c;
        ids[1] = a;
        ids[2] = b;
        vault.claimMany(ids);
    }

    function test_BATCH004_emptyBatchRejected() public {
        uint256[] memory ids = new uint256[](0);
        vm.expectRevert(WellstakeVault.InvalidBatch.selector);
        vault.claimMany(ids);
    }

    function test_BATCH005_duplicateIdsRevert() public {
        uint256 a = _mint(alice, 10 * ONE_USDC);
        _transition(ONE_USDC);

        uint256[] memory ids = new uint256[](2);
        ids[0] = a;
        ids[1] = a;
        vm.expectRevert(WellstakeVault.RequestAlreadyClaimed.selector);
        vault.claimMany(ids);

        // Not partially settled.
        (,,,,,, bool claimed) = vault.requests(a);
        assertFalse(claimed);
        assertEq(nft.ownerOf(a), alice);
    }

    function test_BATCH006_alreadyClaimedRevertsWholeBatch() public {
        uint256 a = _mint(alice, 10 * ONE_USDC);
        uint256 b = _mint(bob, 20 * ONE_USDC);
        _transition(ONE_USDC);
        vault.claim(a);

        uint256[] memory ids = new uint256[](2);
        ids[0] = b;
        ids[1] = a;
        vm.expectRevert(WellstakeVault.RequestAlreadyClaimed.selector);
        vault.claimMany(ids);

        // b must remain unclaimed.
        (,,,,,, bool claimedB) = vault.requests(b);
        assertFalse(claimedB);
        assertEq(nft.ownerOf(b), bob);
    }

    function test_BATCH007_oneRequestFailsRollsBackWholeBatch() public {
        uint256 ok = _mint(alice, 100 * ONE_USDC);
        uint256 bad = _mint(bob, 1); // settles to zero at nav 2e6
        _transition(2_000_000);

        uint256 supplyBefore = wsk.totalSupply();

        uint256[] memory ids = new uint256[](2);
        ids[0] = ok;
        ids[1] = bad;
        vm.expectRevert(WellstakeVault.ZeroSettlement.selector);
        vault.claimMany(ids);

        (,,,,,, bool claimedOk) = vault.requests(ok);
        (,,,,,, bool claimedBad) = vault.requests(bad);
        assertFalse(claimedOk);
        assertFalse(claimedBad);
        assertEq(nft.ownerOf(ok), alice);
        assertEq(nft.ownerOf(bad), bob);
        assertEq(wsk.totalSupply(), supplyBefore);
        assertEq(usdc.balanceOf(address(vault)), 100 * ONE_USDC + 1);
    }

    function test_BATCH008_thirdPartyExecutesBatch() public {
        uint256 a = _mint(alice, 10 * ONE_USDC);
        uint256 b = _mint(bob, 20 * ONE_USDC);
        _transition(ONE_USDC);

        uint256[] memory ids = new uint256[](2);
        ids[0] = a;
        ids[1] = b;
        vm.prank(carol);
        vault.claimMany(ids);

        assertEq(wsk.balanceOf(alice), 10 * ONE_WSK);
        assertEq(wsk.balanceOf(bob), 20 * ONE_WSK);
        assertEq(wsk.balanceOf(carol), 0);
    }
}
