// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {WellstakeTestBase} from "./WellstakeTestBase.sol";
import {WellstakeVault} from "../src/WellstakeVault.sol";

contract RedeemRequestTest is WellstakeTestBase {
    function test_REDEEM001_createValidRedeemRequest() public {
        _giveWSK(alice, 1000 * ONE_WSK);
        uint256 supplyBefore = wsk.totalSupply();

        uint256 gross = 100 * ONE_WSK;
        uint256 expectedFee = gross * FEE_BPS / BPS_DENOMINATOR;
        uint256 expectedNet = gross - expectedFee;

        vm.prank(alice);
        uint256 id = vault.requestRedeem(gross);

        assertEq(id, 2);
        (
            WellstakeVault.RequestType t,
            address owner,
            uint256 epoch,
            uint256 amt,
            uint256 fee,
            uint256 net,
            bool claimed
        ) = vault.requests(id);
        assertEq(uint256(t), uint256(WellstakeVault.RequestType.REDEEM));
        assertEq(owner, alice);
        assertEq(epoch, 2);
        assertEq(amt, gross);
        assertEq(fee, expectedFee);
        assertEq(net, expectedNet);
        assertFalse(claimed);

        assertEq(wsk.balanceOf(feeWallet), expectedFee);
        assertEq(wsk.balanceOf(address(vault)), expectedNet);
        assertEq(nft.ownerOf(id), alice);
        assertEq(wsk.totalSupply(), supplyBefore);
    }

    function test_REDEEM002_feeIsNotBurned() public {
        _giveWSK(alice, 1000 * ONE_WSK);
        uint256 supplyBefore = wsk.totalSupply();

        uint256 gross = 100 * ONE_WSK;
        uint256 fee = gross * FEE_BPS / BPS_DENOMINATOR;
        _requestRedeem(alice, gross);

        assertEq(wsk.balanceOf(feeWallet), fee);
        assertEq(wsk.totalSupply(), supplyBefore);
    }

    function test_REDEEM003_feeWalletIsOrdinaryHolder() public {
        _giveWSK(alice, 1000 * ONE_WSK);
        uint256 gross = 100 * ONE_WSK;
        _requestRedeem(alice, gross);

        uint256 fee = gross * FEE_BPS / BPS_DENOMINATOR;
        assertEq(wsk.balanceOf(feeWallet), fee);

        // feeWallet can transfer its WSK like any holder.
        vm.prank(feeWallet);
        wsk.transfer(bob, fee);
        assertEq(wsk.balanceOf(bob), fee);
    }

    function test_REDEEM004_zeroAmountRejected() public {
        _giveWSK(alice, 1000 * ONE_WSK);
        vm.prank(alice);
        vm.expectRevert(WellstakeVault.ZeroAmount.selector);
        vault.requestRedeem(0);
    }

    function test_REDEEM005_insufficientWskRejected() public {
        _giveWSK(alice, 100 * ONE_WSK);
        vm.prank(alice);
        vm.expectRevert();
        vault.requestRedeem(200 * ONE_WSK);

        assertEq(wsk.balanceOf(feeWallet), 0);
        assertEq(wsk.balanceOf(alice), 100 * ONE_WSK);
    }

    function test_REDEEM006_pendingRedeemDoesNotBurnWsk() public {
        _giveWSK(alice, 1000 * ONE_WSK);
        uint256 supplyBefore = wsk.totalSupply();

        _requestRedeem(alice, 100 * ONE_WSK);

        assertEq(wsk.totalSupply(), supplyBefore);
    }
}
