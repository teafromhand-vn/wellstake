// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {WellstakeTestBase} from "./WellstakeTestBase.sol";

contract DirectTransferTest is WellstakeTestBase {
    function test_DIRECT001_directUsdcTransferToVault() public {
        _fundUSDC(alice, 50 * ONE_USDC);
        vm.prank(alice);
        usdc.transfer(address(vault), 50 * ONE_USDC);

        // No request, no NFT, no entitlement.
        assertEq(vault.nextRequestId(), 1);
        (, address owner0,,,,,) = vault.requests(0);
        assertEq(owner0, address(0));
        assertEq(usdc.balanceOf(address(vault)), 50 * ONE_USDC);
        assertEq(nft.balanceOf(alice), 0);
    }

    function test_DIRECT002_directWskTransferToVault() public {
        _giveWSK(alice, 100 * ONE_WSK);
        uint256 supplyBefore = wsk.totalSupply();

        vm.prank(alice);
        wsk.transfer(address(vault), 25 * ONE_WSK);

        // No redeem request, no automatic burn, supply unchanged.
        assertEq(vault.nextRequestId(), 2); // only the earlier mint request
        assertEq(wsk.balanceOf(address(vault)), 25 * ONE_WSK);
        assertEq(wsk.totalSupply(), supplyBefore);
    }
}
