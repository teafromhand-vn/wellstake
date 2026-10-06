// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {WellstakeTestBase} from "./WellstakeTestBase.sol";
import {WellstakeVault} from "../src/WellstakeVault.sol";

contract MintSettleTest is WellstakeTestBase {
    function test_MINTSET001_claimBeforeFinalizationRejected() public {
        uint256 id = _mint(alice, 100 * ONE_USDC);

        vm.expectRevert(WellstakeVault.EpochNotFinalized.selector);
        vault.claim(id);

        (,,,,,, bool claimed) = vault.requests(id);
        assertFalse(claimed);
        assertEq(nft.ownerOf(id), alice);
        assertEq(wsk.totalSupply(), 0);
    }

    function test_MINTSET002_claimAfterFinalization() public {
        uint256 id = _mint(alice, 100 * ONE_USDC);
        _transition(ONE_USDC);

        vault.claim(id);

        assertEq(wsk.balanceOf(alice), 100 * ONE_WSK);
        assertEq(wsk.totalSupply(), 100 * ONE_WSK);
        // Escrowed USDC becomes fund capital (stays in the Vault).
        assertEq(usdc.balanceOf(address(vault)), 100 * ONE_USDC);

        (,,,,,, bool claimed) = vault.requests(id);
        assertTrue(claimed);
        vm.expectRevert();
        nft.ownerOf(id);
    }

    function test_MINTSET003_thirdPartyCanClaimForUser() public {
        uint256 id = _mint(alice, 100 * ONE_USDC);
        _transition(ONE_USDC);

        vm.prank(carol);
        vault.claim(id);

        assertEq(wsk.balanceOf(alice), 100 * ONE_WSK);
        assertEq(wsk.balanceOf(carol), 0);
    }

    function test_MINTSET004_usesLockedEpochNav() public {
        uint256 id = _mint(alice, 100 * ONE_USDC); // epoch 1
        _transition(ONE_USDC); // epoch 1 nav = 0.04 scale? ONE_USDC = 1e6 = 1.0
        _transition(2 * ONE_USDC); // epoch 2 nav

        vault.claim(id);
        // Epoch 1 nav = 1e6 -> 100 WSK, not epoch 2 nav.
        assertEq(wsk.balanceOf(alice), 100 * ONE_WSK);
    }

    function test_MINTSET005_roundsDown() public {
        // nav such that division is fractional. amount=100, nav=3 (raw) -> floor(100e6/3).
        uint256 id = _mint(alice, 100);
        _transition(3);

        vault.claim(id);
        assertEq(wsk.balanceOf(alice), uint256(100 * 1e6) / 3); // 33_333_333
    }

    function test_MINTSET006_zeroSettlementReverts() public {
        // amount * 1e6 < nav => floor = 0.
        uint256 id = _mint(alice, 1);
        _transition(2_000_000);

        vm.expectRevert(WellstakeVault.ZeroSettlement.selector);
        vault.claim(id);

        (,,,,,, bool claimed) = vault.requests(id);
        assertFalse(claimed);
        assertEq(nft.ownerOf(id), alice);
        assertEq(usdc.balanceOf(address(vault)), 1);
    }

    function test_MINTSET007_failedClaimIsAtomic() public {
        uint256 valid = _mint(alice, 100);
        uint256 tiny = _mint(bob, 1);
        _transition(2_000_000);

        vm.expectRevert(WellstakeVault.ZeroSettlement.selector);
        vault.claim(tiny);

        assertEq(wsk.totalSupply(), 0);
        (,,,,,, bool claimedTiny) = vault.requests(tiny);
        assertFalse(claimedTiny);
        assertEq(nft.ownerOf(tiny), bob);
        assertEq(usdc.balanceOf(address(vault)), 101);

        // The valid request still settles.
        vault.claim(valid);
        assertEq(wsk.balanceOf(alice), uint256(100 * 1e6) / 2_000_000); // 50 raw WSK
    }
}
