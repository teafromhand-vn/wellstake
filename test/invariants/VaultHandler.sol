// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {WellstakeVault} from "../../src/WellstakeVault.sol";
import {WellstakeToken} from "../../src/WellstakeToken.sol";
import {PendingRequestNFT} from "../../src/PendingRequestNFT.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";

/// @dev Drives randomized Vault interactions for the invariant suite. Action functions must not
///      revert, so invalid inputs are skipped rather than reverted.
contract VaultHandler is Test {
    uint256 internal constant ONE = 1e6;

    WellstakeVault public vault;
    WellstakeToken public wsk;
    PendingRequestNFT public nft;
    MockUSDC public usdc;

    address public manager;
    address public liquidWallet;
    address public feeWallet;
    address[] public actors;

    mapping(uint256 => address) public ghost_owner;
    mapping(uint256 => uint256) public ghost_epoch;
    mapping(uint256 => bool) public ghost_seen;

    mapping(uint256 => uint256) public ghost_finalNav;
    mapping(uint256 => bool) public ghost_hasFinalNav;

    constructor(
        WellstakeVault vault_,
        MockUSDC usdc_,
        address manager_,
        address liquidWallet_,
        address feeWallet_
    ) {
        vault = vault_;
        wsk = vault_.wsk();
        nft = vault_.pendingNFT();
        usdc = usdc_;
        manager = manager_;
        liquidWallet = liquidWallet_;
        feeWallet = feeWallet_;

        actors.push(makeAddr("actor0"));
        actors.push(makeAddr("actor1"));
        actors.push(makeAddr("actor2"));

        for (uint256 i = 0; i < actors.length; i++) {
            usdc.mint(actors[i], 1_000_000 * ONE);
            vm.prank(actors[i]);
            usdc.approve(address(vault), type(uint256).max);
        }

        usdc.mint(liquidWallet, type(uint256).max / 2);
        vm.prank(liquidWallet);
        usdc.approve(address(vault), type(uint256).max);
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    function requestMint(uint256 seed, uint256 amount) external {
        if (vault.woundDown()) return;
        address actor = _actor(seed);
        uint256 bal = usdc.balanceOf(actor);
        if (bal == 0) return;
        amount = bound(amount, 1, bal);

        vm.prank(actor);
        uint256 id = vault.requestMint(amount);
        ghost_owner[id] = actor;
        ghost_epoch[id] = vault.currentEpoch();
        ghost_seen[id] = true;
    }

    function requestRedeem(uint256 seed, uint256 amount) external {
        if (vault.woundDown()) return;
        address actor = _actor(seed);
        uint256 bal = wsk.balanceOf(actor);
        if (bal == 0) return;
        amount = bound(amount, 1, bal);

        vm.prank(actor);
        uint256 id = vault.requestRedeem(amount);
        ghost_owner[id] = actor;
        ghost_epoch[id] = vault.currentEpoch();
        ghost_seen[id] = true;
    }

    function transition(uint256 nav) external {
        if (vault.woundDown()) return;
        if (wsk.totalSupply() > 0 && nav == 0) nav = 1;
        nav = bound(nav, 1, 1_000_000 * ONE);

        uint256 epoch = vault.currentEpoch();
        vm.prank(manager);
        vault.transitionEpoch(nav);
        ghost_finalNav[epoch] = nav;
        ghost_hasFinalNav[epoch] = true;
    }

    function windDown(uint256 nav) external {
        if (vault.woundDown()) return;
        if (wsk.totalSupply() > 0 && nav == 0) nav = 1;
        nav = bound(nav, 1, 1_000_000 * ONE);

        uint256 epoch = vault.currentEpoch();
        vm.prank(manager);
        vault.pause(nav);
        ghost_finalNav[epoch] = nav;
        ghost_hasFinalNav[epoch] = true;
    }

    function claim(uint256 id) external {
        uint256 next = vault.nextRequestId();
        if (next <= 1) return;
        id = bound(id, 1, next - 1);
        try vault.claim(id) {} catch {}
    }

    function claimMany(uint256 seedA, uint256 seedB) external {
        uint256 next = vault.nextRequestId();
        if (next <= 2) return;
        uint256 a = bound(seedA, 1, next - 1);
        uint256 b = bound(seedB, 1, next - 1);
        if (a == b) return;

        uint256[] memory ids = new uint256[](2);
        ids[0] = a;
        ids[1] = b;
        try vault.claimMany(ids) {} catch {}
    }

    function actorCount() external view returns (uint256) {
        return actors.length;
    }
}
