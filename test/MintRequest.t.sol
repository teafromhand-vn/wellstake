// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {WellstakeTestBase} from "./WellstakeTestBase.sol";
import {WellstakeVault} from "../src/WellstakeVault.sol";

contract MintRequestTest is WellstakeTestBase {
    function test_MINT001_createValidMintRequest() public {
        uint256 amount = 100 * ONE_USDC;
        _fundUSDC(alice, amount);
        _approveUSDC(alice, amount);

        uint256 supplyBefore = wsk.totalSupply();
        vm.prank(alice);
        uint256 id = vault.requestMint(amount);

        assertEq(id, 1);
        assertEq(vault.nextRequestId(), 2);
        assertEq(usdc.balanceOf(address(vault)), amount);

        (WellstakeVault.RequestType t, address owner, uint256 epoch, uint256 amt,,, bool claimed) =
            vault.requests(id);
        assertEq(uint256(t), uint256(WellstakeVault.RequestType.MINT));
        assertEq(owner, alice);
        assertEq(epoch, 1);
        assertEq(amt, amount);
        assertFalse(claimed);

        assertEq(nft.ownerOf(id), alice);
        assertEq(wsk.totalSupply(), supplyBefore);
    }

    function test_MINT002_zeroAmountRejected() public {
        vm.prank(alice);
        vm.expectRevert(WellstakeVault.ZeroAmount.selector);
        vault.requestMint(0);
        assertEq(vault.nextRequestId(), 1);
    }

    function test_MINT003_insufficientUsdcRejected() public {
        _fundUSDC(alice, 5 * ONE_USDC);
        _approveUSDC(alice, 5 * ONE_USDC);

        vm.prank(alice);
        vm.expectRevert();
        vault.requestMint(10 * ONE_USDC);

        assertEq(vault.nextRequestId(), 1);
        assertEq(usdc.balanceOf(address(vault)), 0);
    }

    function test_MINT004_pendingUsdcRemainsInVault() public {
        uint256 id = _mint(alice, 100 * ONE_USDC);
        assertEq(usdc.balanceOf(address(vault)), 100 * ONE_USDC);
        assertEq(usdc.balanceOf(vaultWallet), 0);
        assertTrue(nft.ownerOf(id) != address(0));
    }

    function test_MINT005_pendingMintDoesNotMintWsk() public {
        _mint(alice, 100 * ONE_USDC);
        assertEq(wsk.totalSupply(), 0);
        assertEq(wsk.balanceOf(alice), 0);
    }

    function test_MINT006_recordsCurrentEpoch() public {
        uint256 id1 = _mint(alice, 10 * ONE_USDC);
        _transition(ONE_USDC);
        uint256 id2 = _mint(bob, 10 * ONE_USDC);

        (,, uint256 e1,,,,) = vault.requests(id1);
        (,, uint256 e2,,,,) = vault.requests(id2);
        assertEq(e1, 1);
        assertEq(e2, 2);
    }

    function test_MINT007_nftIsNonTransferable() public {
        uint256 id = _mint(alice, 10 * ONE_USDC);

        vm.prank(alice);
        vm.expectRevert();
        nft.transferFrom(alice, bob, id);

        vm.prank(alice);
        nft.approve(bob, id);
        vm.prank(bob);
        vm.expectRevert();
        nft.transferFrom(alice, bob, id);
    }

    function test_MINT008_ownerIsFixed() public {
        uint256 id = _mint(alice, 10 * ONE_USDC);
        (, address owner,,,,,) = vault.requests(id);
        assertEq(owner, alice);

        vm.prank(alice);
        (bool ok,) = address(nft)
            .call(
                abi.encodeWithSignature("safeTransferFrom(address,address,uint256)", alice, bob, id)
            );
        assertFalse(ok);

        (, owner,,,,,) = vault.requests(id);
        assertEq(owner, alice);
    }
}
