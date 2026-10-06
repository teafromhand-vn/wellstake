// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {WellstakeTestBase} from "./WellstakeTestBase.sol";
import {LiquidWallet} from "../src/LiquidWallet.sol";

contract MintTest is WellstakeTestBase {
    function test_createMintRequest() public {
        uint256 amount = 100 * ONE;
        uint256 id = _requestMint(alice, amount);

        assertEq(id, 1);
        assertEq(usdc.balanceOf(address(liquid)), amount);
        assertEq(nft.ownerOf(id), alice);
        assertEq(wsk.totalSupply(), 0); // not minted at request time

        (
            LiquidWallet.RequestType t,
            address owner,
            uint256 amt,
            uint256 fee,
            uint256 net,
            bool claimed
        ) = liquid.requests(id);
        assertEq(uint256(t), uint256(LiquidWallet.RequestType.MINT));
        assertEq(owner, alice);
        assertEq(amt, amount);
        assertEq(fee, 0);
        assertEq(net, 0);
        assertFalse(claimed);
    }

    function test_zeroAmountRejected() public {
        vm.prank(alice);
        vm.expectRevert(LiquidWallet.ZeroAmount.selector);
        liquid.requestMint(0);
        assertEq(liquid.nextRequestId(), 1);
    }

    function test_insufficientUsdcRejected() public {
        _fundUSDC(alice, 5 * ONE);
        _approveUSDC(alice, 5 * ONE);
        vm.prank(alice);
        vm.expectRevert();
        liquid.requestMint(10 * ONE);
        assertEq(liquid.nextRequestId(), 1);
    }

    function test_claimUsesRate() public {
        uint256 id = _requestMint(alice, 100 * ONE);
        // rate initially = INITIAL_NAV (38462). WSK = 100e6 * 1e6 / 38462.
        uint256 expected = uint256(100 * ONE) * 1e6 / INITIAL_NAV;
        liquid.claim(id);
        assertEq(wsk.balanceOf(alice), expected);
    }

    function test_claimAfterNavUpdate() public {
        uint256 id = _requestMint(alice, 100 * ONE);
        _setNav(0); // supply is 0 -> rate unchanged
        _setNav(200 * ONE); // still supply 0 -> rate unchanged
        // rate stays INITIAL_NAV because supply == 0
        assertEq(liquid.rate(), INITIAL_NAV);
    }

    function test_thirdPartyCanClaimToOwner() public {
        uint256 id = _requestMint(alice, 100 * ONE);
        vm.prank(carol);
        liquid.claim(id);
        assertGt(wsk.balanceOf(alice), 0);
        assertEq(wsk.balanceOf(carol), 0);
    }

    function test_nftBurnedAfterClaim() public {
        uint256 id = _requestMint(alice, 100 * ONE);
        liquid.claim(id);
        vm.expectRevert();
        nft.ownerOf(id);
    }

    function test_doubleClaimReverts() public {
        uint256 id = _requestMint(alice, 100 * ONE);
        liquid.claim(id);
        vm.expectRevert(LiquidWallet.RequestAlreadyClaimed.selector);
        liquid.claim(id);
    }

    function test_claimUnknownReverts() public {
        vm.expectRevert(LiquidWallet.RequestNotFound.selector);
        liquid.claim(999);
    }
}
