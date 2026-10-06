// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {WellstakeTestBase} from "./WellstakeTestBase.sol";
import {ReentrantUSDC} from "./mocks/ReentrantUSDC.sol";
import {WellstakeVault} from "../src/WellstakeVault.sol";
import {WellstakeToken} from "../src/WellstakeToken.sol";
import {PendingRequestNFT} from "../src/PendingRequestNFT.sol";

contract SecurityTest is WellstakeTestBase {
    ReentrantUSDC internal reUsdc;
    WellstakeVault internal reVault;
    WellstakeToken internal reWsk;
    PendingRequestNFT internal reNft;

    function _deployReentrant() internal {
        reUsdc = new ReentrantUSDC();
        reVault = new WellstakeVault(address(reUsdc), manager, vaultWallet, liquidWallet, feeWallet);
        reWsk = reVault.wsk();
        reNft = reVault.pendingNFT();
    }

    function test_SEC001_reentrancyOnRequestMint() public {
        _deployReentrant();
        reUsdc.mint(alice, 100 * ONE_USDC);
        vm.prank(alice);
        reUsdc.approve(address(reVault), type(uint256).max);

        // Attack: reenter requestMint during the escrow transfer.
        bytes memory payload = abi.encodeWithSignature("requestMint(uint256)", 1);
        reUsdc.setAttack(address(reVault), payload);

        vm.prank(alice);
        vm.expectRevert();
        reVault.requestMint(10 * ONE_USDC);
    }

    function test_SEC002_reentrantRedeemClaimCannotDoubleSettle() public {
        _deployReentrant();
        // Give alice WSK at nav 1e6.
        reUsdc.mint(alice, 1000 * ONE_USDC);
        vm.prank(alice);
        reUsdc.approve(address(reVault), type(uint256).max);
        vm.prank(alice);
        uint256 mintId = reVault.requestMint(1000 * ONE_USDC);
        vm.prank(manager);
        reVault.transitionEpoch(ONE_USDC);
        reVault.claim(mintId);

        // Create redeem request in epoch 2.
        vm.prank(alice);
        reWsk.approve(address(reVault), type(uint256).max);
        vm.prank(alice);
        uint256 rid = reVault.requestRedeem(100 * ONE_WSK);
        vm.prank(manager);
        reVault.transitionEpoch(ONE_USDC); // finalize epoch 2

        // Fund liquid wallet and approve.
        reUsdc.mint(liquidWallet, 1000 * ONE_USDC);
        vm.prank(liquidWallet);
        reUsdc.approve(address(reVault), type(uint256).max);

        // On the USDC payout transfer, reenter claim(rid).
        reUsdc.setAttack(address(reVault), abi.encodeWithSignature("claim(uint256)", rid));

        vm.expectRevert(); // ReentrancyGuard blocks; attack bubbles.
        reVault.claim(rid);

        // Request is not settled.
        (,,,,,, bool claimed) = reVault.requests(rid);
        assertFalse(claimed);
        assertEq(reNft.ownerOf(rid), alice);
    }

    function test_SEC002b_reentrantRedeemSwallowedStillNoDoubleSettle() public {
        _deployReentrant();
        reUsdc.mint(alice, 1000 * ONE_USDC);
        vm.prank(alice);
        reUsdc.approve(address(reVault), type(uint256).max);
        vm.prank(alice);
        uint256 mintId = reVault.requestMint(1000 * ONE_USDC);
        vm.prank(manager);
        reVault.transitionEpoch(ONE_USDC);
        reVault.claim(mintId);

        vm.prank(alice);
        reWsk.approve(address(reVault), type(uint256).max);
        vm.prank(alice);
        uint256 rid = reVault.requestRedeem(100 * ONE_WSK);
        vm.prank(manager);
        reVault.transitionEpoch(ONE_USDC);

        reUsdc.mint(liquidWallet, 1000 * ONE_USDC);
        vm.prank(liquidWallet);
        reUsdc.approve(address(reVault), type(uint256).max);

        reUsdc.setBubbleUp(false);
        reUsdc.setAttack(address(reVault), abi.encodeWithSignature("claim(uint256)", rid));

        reVault.claim(rid);

        assertFalse(reUsdc.attackSucceeded());
        (,,,,,, bool claimed) = reVault.requests(rid);
        assertTrue(claimed);
        // Only settled once.
        assertEq(reWsk.balanceOf(address(reVault)), 0);
    }

    function test_SEC003_failedUsdcTransferRevertsClaim() public {
        _giveWSK(alice, 1000 * ONE_WSK);
        uint256 id = _requestRedeem(alice, 100 * ONE_WSK);
        _transition(ONE_USDC);
        // liquidWallet has no USDC / no approval.

        uint256 supplyBefore = wsk.totalSupply();
        vm.expectRevert();
        vault.claim(id);

        (,,,,,, bool claimed) = vault.requests(id);
        assertFalse(claimed);
        assertEq(nft.ownerOf(id), alice);
        assertEq(wsk.totalSupply(), supplyBefore);
        assertEq(usdc.balanceOf(alice), 0);
    }

    function test_SEC004_failedWskOperationRevertsAtomically() public {
        // Redeem request creation fails if user lacks WSK; no partial state remains.
        vm.prank(alice);
        vm.expectRevert();
        vault.requestRedeem(100 * ONE_WSK);

        assertEq(vault.nextRequestId(), 1);
        assertEq(wsk.balanceOf(address(vault)), 0);
        assertEq(wsk.balanceOf(feeWallet), 0);
    }

    function test_SEC005_batchRollback() public {
        uint256 ok = _mint(alice, 100 * ONE_USDC);
        uint256 bad = _mint(bob, 1);
        _transition(2_000_000);

        uint256[] memory ids = new uint256[](2);
        ids[0] = ok;
        ids[1] = bad;
        vm.expectRevert(WellstakeVault.ZeroSettlement.selector);
        vault.claimMany(ids);

        (,,,,,, bool claimedOk) = vault.requests(ok);
        assertFalse(claimedOk);
        assertEq(nft.ownerOf(ok), alice);
        assertEq(wsk.totalSupply(), 0);
    }
}
