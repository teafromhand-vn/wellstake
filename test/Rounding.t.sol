// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {WellstakeTestBase} from "./WellstakeTestBase.sol";

contract RoundingTest is WellstakeTestBase {
    function test_ROUND001_mintRoundsDown() public {
        // floor(1000 * 1e6 / 3) = 333_333_333
        uint256 id = _mint(alice, 1000);
        _transition(3);
        vault.claim(id);
        uint256 out = wsk.balanceOf(alice);
        assertEq(out, uint256(1000 * 1e6) / 3);

        // verify never rounds up
        assertLe(out * 3, 1000 * 1e6);
    }

    function test_ROUND002_redeemRoundsDown() public {
        _giveWSK(alice, 100 * ONE_WSK);
        uint256 gross = 100 * ONE_WSK;
        uint256 net = gross - gross * FEE_BPS / BPS_DENOMINATOR;
        uint256 id = _requestRedeem(alice, gross);
        uint256 nav = 3_333_333; // ~3.333333
        _transition(nav);
        _fundLiquid(1000 * ONE_USDC);

        vault.claim(id);
        uint256 expected = net * nav / 1e6;
        assertEq(usdc.balanceOf(alice), expected);
        assertLe(expected * 1e6, net * nav); // never rounded up
    }

    function test_ROUND003_multiplyBeforeDivide() public {
        // Values where dividing first loses precision.
        uint256 amount = 999_999_999_999;
        _fundUSDC(alice, amount);
        _approveUSDC(alice, amount);
        uint256 id = _requestMint(alice, amount);

        uint256 nav = 7;
        _transition(nav);

        vault.claim(id);
        assertEq(wsk.balanceOf(alice), amount * 1e6 / nav); // exact floor via mulDiv
    }

    function test_ROUND004_feeRounding() public {
        // gross = 199 => fee = floor(199*50/10000) = 0
        _giveWSK(alice, 1000);
        vm.prank(alice);
        uint256 id = vault.requestRedeem(199);
        (,,, uint256 amt, uint256 fee, uint256 net,) = vault.requests(id);
        assertEq(amt, 199);
        assertEq(fee, 0);
        assertEq(net, 199);

        // gross = 200 => fee = 1
        vm.prank(alice);
        uint256 id2 = vault.requestRedeem(200);
        (,,,, uint256 fee2, uint256 net2,) = vault.requests(id2);
        assertEq(fee2, 1);
        assertEq(net2, 199);
    }

    function test_ROUND005_splitRedemptionDifferentAggregateFee() public {
        _giveWSK(alice, 1000);
        // Split: two 100 gross -> fee floor(0.5)=0 each => total fee 0.
        vm.prank(alice);
        uint256 a = vault.requestRedeem(100);
        vm.prank(alice);
        uint256 b = vault.requestRedeem(100);
        (,,,, uint256 feeA,,) = vault.requests(a);
        (,,,, uint256 feeB,,) = vault.requests(b);

        // Single: 200 gross -> fee 1.
        vm.prank(alice);
        uint256 c = vault.requestRedeem(200);
        (,,,, uint256 feeC,,) = vault.requests(c);

        assertEq(feeA + feeB, 0);
        assertEq(feeC, 1);
    }
}
