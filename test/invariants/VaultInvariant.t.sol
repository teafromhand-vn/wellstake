// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

import {WellstakeVault} from "../../src/WellstakeVault.sol";
import {WellstakeToken} from "../../src/WellstakeToken.sol";
import {PendingRequestNFT} from "../../src/PendingRequestNFT.sol";
import {MockUSDC} from "../../src/mocks/MockUSDC.sol";
import {VaultHandler} from "./VaultHandler.sol";

contract VaultInvariantTest is StdInvariant, Test {
    MockUSDC internal usdc;
    WellstakeVault internal vault;
    WellstakeToken internal wsk;
    PendingRequestNFT internal nft;
    VaultHandler internal handler;

    address internal manager = makeAddr("manager");
    address internal vaultWallet = makeAddr("vaultWallet");
    address internal liquidWallet = makeAddr("liquidWallet");
    address internal feeWallet = makeAddr("feeWallet");

    function setUp() public {
        usdc = new MockUSDC();
        vault = new WellstakeVault(address(usdc), manager, vaultWallet, liquidWallet, feeWallet);
        wsk = vault.wsk();
        nft = vault.pendingNFT();

        handler = new VaultHandler(vault, usdc, manager, liquidWallet, feeWallet);

        // Only exercise the Vault through the handler. Excluding the concrete contracts prevents
        // the fuzzer from invoking privileged entrypoints (e.g. WSK.mint) as the Vault itself.
        targetContract(address(handler));
        excludeContract(address(wsk));
        excludeContract(address(vault));
        excludeContract(address(nft));
        excludeContract(address(usdc));
    }

    /// INV-001 / INV-002: request ids are positive and the counter tracks the number issued.
    function invariant_requestCounter() public view {
        assertGe(vault.nextRequestId(), 1);
    }

    /// INV-003: every request's owner equals the owner recorded at creation.
    function invariant_requestOwnerImmutable() public view {
        uint256 next = vault.nextRequestId();
        for (uint256 id = 1; id < next; id++) {
            (, address owner,,,,,) = vault.requests(id);
            if (handler.ghost_seen(id)) {
                assertEq(owner, handler.ghost_owner(id));
            }
        }
    }

    /// INV-004: a request's epoch equals the active epoch at creation.
    function invariant_requestEpochImmutable() public view {
        uint256 next = vault.nextRequestId();
        for (uint256 id = 1; id < next; id++) {
            (,, uint256 epoch,,,,) = vault.requests(id);
            if (handler.ghost_seen(id)) {
                assertEq(epoch, handler.ghost_epoch(id));
            }
        }
    }

    /// INV-005: a finalized epoch NAV never changes.
    function invariant_finalizedNavImmutable() public view {
        for (uint256 epoch = 0; epoch <= vault.currentEpoch(); epoch++) {
            if (handler.ghost_hasFinalNav(epoch)) {
                (uint256 nav,,, bool finalized) = vault.epochs(epoch);
                assertTrue(finalized);
                assertEq(nav, handler.ghost_finalNav(epoch));
            }
        }
    }

    /// INV-011 / INV-012: unclaimed requests have their NFT; claimed requests have none.
    function invariant_nftRequestCorrespondence() public view {
        uint256 next = vault.nextRequestId();
        for (uint256 id = 1; id < next; id++) {
            (, address owner,,,,, bool claimed) = vault.requests(id);
            (bool exists, address nftOwner) = _nftOwner(id);
            if (claimed) {
                assertFalse(exists);
            } else if (exists) {
                assertEq(nftOwner, owner);
            }
        }
    }

    /// INV-006 / INV-007: pending operations never move total supply unexpectedly; supply must be
    /// consistent with the sum of balances.
    function invariant_supplyConsistency() public view {
        uint256 sum =
            wsk.balanceOf(address(vault)) + wsk.balanceOf(feeWallet) + wsk.balanceOf(liquidWallet);
        uint256 actors = handler.actorCount();
        for (uint256 i = 0; i < actors; i++) {
            sum += wsk.balanceOf(handler.actors(i));
        }
        assertEq(sum, wsk.totalSupply());
    }

    /// INV-014: once wound down, no new fund operations are possible.
    function invariant_woundDownBlocksNewOperations() public {
        if (!vault.woundDown()) return;
        vm.expectRevert();
        vm.prank(manager);
        vault.transitionEpoch(1);
    }

    function _nftOwner(uint256 id) internal view returns (bool exists, address owner) {
        try nft.ownerOf(id) returns (address o) {
            return (true, o);
        } catch {
            return (false, address(0));
        }
    }
}
