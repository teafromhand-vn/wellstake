// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {WellstakeTestBase} from "./WellstakeTestBase.sol";
import {PendingRequestNFT} from "../src/PendingRequestNFT.sol";

contract PendingNFTTest is WellstakeTestBase {
    function test_NFT001_sharedForMintAndRedeem() public {
        _giveWSK(alice, 1000 * ONE_WSK);
        uint256 mintId = _mint(bob, 10 * ONE_USDC);
        uint256 redeemId = _requestRedeem(alice, 10 * ONE_WSK);

        // Same contract, token ids equal request ids.
        assertEq(nft.ownerOf(mintId), bob);
        assertEq(nft.ownerOf(redeemId), alice);
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.balanceOf(bob), 1);
    }

    function test_NFT002_tokenIdEqualsRequestId() public {
        uint256 id = _mint(alice, 10 * ONE_USDC);
        assertEq(id, 1);
        assertEq(nft.ownerOf(1), alice);
    }

    function test_NFT003_burnedOnSuccessfulClaim() public {
        uint256 id = _mint(alice, 100 * ONE_USDC);
        _transition(ONE_USDC);
        vault.claim(id);

        vm.expectRevert();
        nft.ownerOf(id);
        assertEq(nft.balanceOf(alice), 0);
    }

    function test_NFT004_survivesFailedClaim() public {
        uint256 id = _mint(alice, 1);
        _transition(2_000_000);

        vm.expectRevert();
        vault.claim(id);
        assertEq(nft.ownerOf(id), alice);
    }

    function test_NFT005_cannotBeTransferred() public {
        uint256 id = _mint(alice, 10 * ONE_USDC);
        vm.prank(alice);
        vm.expectRevert(PendingRequestNFT.NonTransferable.selector);
        nft.transferFrom(alice, bob, id);

        vm.prank(alice);
        nft.setApprovalForAll(bob, true);
        vm.prank(bob);
        vm.expectRevert(PendingRequestNFT.NonTransferable.selector);
        nft.transferFrom(alice, bob, id);
    }

    function test_NFT_onlyVaultCanMintAndBurn() public {
        vm.prank(alice);
        vm.expectRevert(PendingRequestNFT.NotVault.selector);
        nft.mint(alice, 999);

        uint256 id = _mint(alice, 10 * ONE_USDC);
        vm.prank(alice);
        vm.expectRevert(PendingRequestNFT.NotVault.selector);
        nft.burn(id);
    }
}
