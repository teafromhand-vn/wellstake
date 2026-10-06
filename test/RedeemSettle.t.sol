// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {WellstakeTestBase} from "./WellstakeTestBase.sol";
import {WellstakeVault} from "../src/WellstakeVault.sol";

contract RedeemSettleTest is WellstakeTestBase {
    function test_REDEEMSET001_claimBeforeFinalizationRejected() public {
        _giveWSK(alice, 1000 * ONE_WSK);
        uint256 id = _requestRedeem(alice, 100 * ONE_WSK);

        vm.expectRevert(WellstakeVault.EpochNotFinalized.selector);
        vault.claim(id);

        (,,,,,, bool claimed) = vault.requests(id);
        assertFalse(claimed);
        assertEq(nft.ownerOf(id), alice);
        assertEq(
            wsk.balanceOf(address(vault)),
            100 * ONE_WSK - (100 * ONE_WSK * FEE_BPS / BPS_DENOMINATOR)
        );
    }

    function test_REDEEMSET002_successfulRedeemClaim() public {
        _giveWSK(alice, 1000 * ONE_WSK);
        uint256 gross = 100 * ONE_WSK;
        uint256 net = gross - gross * FEE_BPS / BPS_DENOMINATOR;
        uint256 id = _requestRedeem(alice, gross);

        _transition(ONE_USDC);
        _fundLiquid(1000 * ONE_USDC);
        uint256 supplyBefore = wsk.totalSupply();

        vault.claim(id);

        uint256 usdcOut = net * ONE_USDC / 1e6; // nav = 1e6
        assertEq(usdc.balanceOf(alice), usdcOut);
        assertEq(wsk.balanceOf(address(vault)), 0);
        assertEq(wsk.totalSupply(), supplyBefore - net);

        (,,,,,, bool claimed) = vault.requests(id);
        assertTrue(claimed);
        vm.expectRevert();
        nft.ownerOf(id);
    }

    function test_REDEEMSET003_settlementUsesEpochNav() public {
        _giveWSK(alice, 1000 * ONE_WSK);
        uint256 net = 100 * ONE_WSK - (100 * ONE_WSK * FEE_BPS / BPS_DENOMINATOR);
        uint256 id = _requestRedeem(alice, 100 * ONE_WSK);

        // Epoch 2 finalized at nav = 2e6, later epoch changes.
        _transition(2 * ONE_USDC);
        _transition(9 * ONE_USDC);
        _fundLiquid(1000 * ONE_USDC);

        vault.claim(id);
        assertEq(usdc.balanceOf(alice), net * 2); // net * 2e6 / 1e6
    }

    function test_REDEEMSET004_insufficientLiquidity() public {
        _giveWSK(alice, 1000 * ONE_WSK);
        uint256 id = _requestRedeem(alice, 100 * ONE_WSK);
        _transition(ONE_USDC);
        // No liquid funding.
        uint256 supplyBefore = wsk.totalSupply();

        vm.expectRevert(WellstakeVault.InsufficientLiquidity.selector);
        vault.claim(id);

        (,,,,,, bool claimed) = vault.requests(id);
        assertFalse(claimed);
        assertEq(nft.ownerOf(id), alice);
        assertEq(wsk.totalSupply(), supplyBefore);
        assertEq(usdc.balanceOf(alice), 0);
    }

    function test_REDEEMSET005_retryAfterLiquidityAdded() public {
        _giveWSK(alice, 1000 * ONE_WSK);
        uint256 id = _requestRedeem(alice, 100 * ONE_WSK);
        _transition(ONE_USDC);

        vm.expectRevert(WellstakeVault.InsufficientLiquidity.selector);
        vault.claim(id);

        _fundLiquid(1000 * ONE_USDC);
        vault.claim(id);

        (,,,,,, bool claimed) = vault.requests(id);
        assertTrue(claimed);
    }

    function test_REDEEMSET006_thirdPartyCanClaim() public {
        _giveWSK(alice, 1000 * ONE_WSK);
        uint256 net = 100 * ONE_WSK - (100 * ONE_WSK * FEE_BPS / BPS_DENOMINATOR);
        uint256 id = _requestRedeem(alice, 100 * ONE_WSK);
        _transition(ONE_USDC);
        _fundLiquid(1000 * ONE_USDC);

        vm.prank(carol);
        vault.claim(id);

        assertEq(usdc.balanceOf(alice), net);
        assertEq(usdc.balanceOf(carol), 0);
    }

    function test_REDEEMSET007_zeroUsdcSettlement() public {
        _giveWSK(alice, 1000 * ONE_WSK);
        // gross = 1 WSK -> fee 0, net 1. With nav = 1, usdcOut = floor(1 * 1 / 1e6) = 0.
        uint256 id = _requestRedeem(alice, 1);
        _transition(1);
        _fundLiquid(1000 * ONE_USDC);

        vm.expectRevert(WellstakeVault.ZeroSettlement.selector);
        vault.claim(id);

        (,,,,,, bool claimed) = vault.requests(id);
        assertFalse(claimed);
        assertEq(nft.ownerOf(id), alice);
    }
}
