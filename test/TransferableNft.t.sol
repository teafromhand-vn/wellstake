// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {WellstakeTestBase} from "./WellstakeTestBase.sol";
import {LiquidWallet} from "../src/LiquidWallet.sol";
import {PendingRequestNFT} from "../src/PendingRequestNFT.sol";

contract TransferableNftTest is WellstakeTestBase {
    function test_nftIsTransferable() public {
        uint256 id = _requestMint(alice, 100 * ONE);

        vm.prank(alice);
        nft.transferFrom(alice, bob, id);
        assertEq(nft.ownerOf(id), bob);
    }

    function test_holderAtClaimReceivesFunds() public {
        uint256 id = _requestMint(alice, 100 * ONE);

        // Alice sells/transfers the ticket to bob before claim.
        vm.prank(alice);
        nft.transferFrom(alice, bob, id);

        liquid.claim(id);

        // Bob, the holder at claim time, receives the WSK.
        assertGt(wsk.balanceOf(bob), 0);
        assertEq(wsk.balanceOf(alice), 0);
    }

    function test_onlyAuthorityMintsAndBurns() public {
        vm.prank(alice);
        vm.expectRevert(PendingRequestNFT.NotAuthority.selector);
        nft.mint(alice, 123);

        uint256 id = _requestMint(alice, 10 * ONE);
        vm.prank(alice);
        vm.expectRevert(PendingRequestNFT.NotAuthority.selector);
        nft.burn(id);
    }

    function test_batchClaimMixed() public {
        uint256 a = _requestMint(alice, 10 * ONE);
        uint256 b = _requestMint(bob, 20 * ONE);

        uint256[] memory ids = new uint256[](2);
        ids[0] = a;
        ids[1] = b;
        liquid.claimMany(ids);

        assertGt(wsk.balanceOf(alice), 0);
        assertGt(wsk.balanceOf(bob), 0);
    }

    function test_emptyBatchReverts() public {
        uint256[] memory ids = new uint256[](0);
        vm.expectRevert(LiquidWallet.InvalidBatch.selector);
        liquid.claimMany(ids);
    }

    function test_duplicateIdsRevert() public {
        uint256 a = _requestMint(alice, 10 * ONE);
        uint256[] memory ids = new uint256[](2);
        ids[0] = a;
        ids[1] = a;
        vm.expectRevert(LiquidWallet.RequestAlreadyClaimed.selector);
        liquid.claimMany(ids);

        (,,,,, bool claimed) = liquid.requests(a);
        assertFalse(claimed);
    }

    function test_batchAtomicOnFailure() public {
        uint256 a = _requestMint(alice, 10 * ONE);
        // bob requests a redeem, then we drain liquid USDC so the redeem leg fails.
        (, uint256 held) = _giveWSK(bob, 1000 * ONE);
        vm.prank(bob);
        uint256 b = liquid.requestRedeem(held / 2);

        uint256 bal = usdc.balanceOf(address(liquid));
        if (bal > 0) {
            vm.prank(address(liquid));
            usdc.transfer(address(0xDEAD), bal);
        }

        uint256[] memory ids = new uint256[](2);
        ids[0] = a;
        ids[1] = b;
        vm.expectRevert(LiquidWallet.InsufficientLiquidity.selector);
        liquid.claimMany(ids);

        (,,,,, bool claimedA) = liquid.requests(a);
        assertFalse(claimedA);
        assertEq(nft.ownerOf(a), alice);
    }
}
