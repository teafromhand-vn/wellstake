// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {WellstakeTestBase} from "./WellstakeTestBase.sol";
import {LiquidWallet} from "../src/LiquidWallet.sol";

contract RedeemTest is WellstakeTestBase {
    function test_createRedeemRequest() public {
        (, uint256 held) = _giveWSK(alice, 1000 * ONE);
        uint256 supplyBefore = wsk.totalSupply();

        uint256 gross = held / 2;
        uint256 fee = gross * FEE_BPS / BPS_DENOMINATOR;
        uint256 net = gross - fee;

        vm.prank(alice);
        uint256 id = liquid.requestRedeem(gross);

        (
            LiquidWallet.RequestType t,
            address owner,
            uint256 amt,
            uint256 feeStored,
            uint256 netStored,
            bool claimed
        ) = liquid.requests(id);
        assertEq(uint256(t), uint256(LiquidWallet.RequestType.REDEEM));
        assertEq(owner, alice);
        assertEq(amt, gross);
        assertEq(feeStored, fee);
        assertEq(netStored, net);
        assertFalse(claimed);

        // Fee forwarded to manager; supply unchanged.
        assertEq(wsk.balanceOf(manager), fee);
        assertEq(wsk.totalSupply(), supplyBefore);
        assertEq(nft.ownerOf(id), alice);
    }

    function test_zeroAmountRejected() public {
        _giveWSK(alice, 1000 * ONE);
        vm.prank(alice);
        vm.expectRevert(LiquidWallet.ZeroAmount.selector);
        liquid.requestRedeem(0);
    }

    function test_insufficientWskRejected() public {
        (, uint256 held) = _giveWSK(alice, 1000 * ONE);
        vm.prank(alice);
        vm.expectRevert();
        liquid.requestRedeem(held + 1 * ONE);
        assertEq(wsk.balanceOf(manager), 0);
    }

    function test_redeemClaimPaysUsdc() public {
        (, uint256 held) = _giveWSK(alice, 1000 * ONE);
        uint256 gross = held / 2;
        uint256 fee = gross * FEE_BPS / BPS_DENOMINATOR;
        uint256 net = gross - fee;

        vm.prank(alice);
        uint256 id = liquid.requestRedeem(gross);
        _usdcToLiquid(10_000 * ONE);

        uint256 rate = liquid.rate();
        uint256 expectedOut = net * rate / 1e6;
        uint256 before = usdc.balanceOf(alice);

        liquid.claim(id);

        assertEq(usdc.balanceOf(alice) - before, expectedOut);
        // net WSK burned
        assertEq(wsk.balanceOf(address(liquid)), 0);
    }

    function test_insufficientLiquidityReverts() public {
        (, uint256 held) = _giveWSK(alice, 1000 * ONE);
        uint256 gross = held / 2;
        vm.prank(alice);
        uint256 id = liquid.requestRedeem(gross);

        // Drain USDC from liquid so redemption cannot be paid.
        uint256 bal = usdc.balanceOf(address(liquid));
        if (bal > 0) {
            vm.prank(address(liquid));
            usdc.transfer(address(0xDEAD), bal);
        }

        vm.expectRevert(LiquidWallet.InsufficientLiquidity.selector);
        liquid.claim(id);

        (,,,,, bool claimed) = liquid.requests(id);
        assertFalse(claimed);
        assertEq(nft.ownerOf(id), alice);
    }

    function test_thirdPartyCanClaimRedeem() public {
        (, uint256 held) = _giveWSK(alice, 1000 * ONE);
        uint256 gross = held / 2;
        vm.prank(alice);
        uint256 id = liquid.requestRedeem(gross);
        _usdcToLiquid(10_000 * ONE);

        uint256 before = usdc.balanceOf(alice);
        vm.prank(carol);
        liquid.claim(id);

        assertGt(usdc.balanceOf(alice), before);
        assertEq(usdc.balanceOf(carol), 0);
    }
}
