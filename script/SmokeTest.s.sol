// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {WellstakeVault} from "../src/WellstakeVault.sol";
import {WellstakeToken} from "../src/WellstakeToken.sol";
import {PendingRequestNFT} from "../src/PendingRequestNFT.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";

/// @notice Live smoke test against an already-deployed Wellstake V1 stack on OP Sepolia.
/// @dev Env: PRIVATE_KEY (deployer/user), MANAGER_PRIVATE_KEY, VAULT, USDC.
///      Exercises mint + redeem happy paths and all defined failure conditions.
contract SmokeTest is Script {
    uint256 internal constant OP_SEPOLIA_CHAIN_ID = 11155420;

    uint256 internal deployerKey;
    uint256 internal managerKey;
    address internal deployer;
    address internal manager;

    WellstakeVault internal vault;
    WellstakeToken internal wsk;
    PendingRequestNFT internal nft;
    MockUSDC internal usdc;

    uint256 internal pass;
    uint256 internal fail;

    function run() external {
        if (block.chainid != OP_SEPOLIA_CHAIN_ID) revert("not OP Sepolia");

        deployerKey = vm.envUint("PRIVATE_KEY");
        managerKey = vm.envUint("MANAGER_PRIVATE_KEY");
        deployer = vm.addr(deployerKey);
        manager = vm.addr(managerKey);

        vault = WellstakeVault(vm.envAddress("VAULT"));
        usdc = MockUSDC(vm.envAddress("USDC"));
        wsk = vault.wsk();
        nft = vault.pendingNFT();

        console.log("== Wellstake live smoke test ==");
        console.log("vault ", address(vault));
        console.log("deployer", deployer);
        console.log("manager ", manager);

        _fundManagerIfNeeded();
        _scenarios();

        console.log("-------------------------------------");
        console.log("PASS", pass);
        console.log("FAIL", fail);
        if (fail != 0) revert("smoke test had failures");
    }

    // ------------------------------------------------------------------
    // Funding
    // ------------------------------------------------------------------
    function _fundManagerIfNeeded() internal {
        if (manager.balance < 0.0005 ether) {
            console.log("[setup] funding manager with 0.001 ETH");
            vm.startBroadcast(deployerKey);
            payable(manager).transfer(0.001 ether);
            vm.stopBroadcast();
        }
    }

    // ------------------------------------------------------------------
    // Scenario driver
    // ------------------------------------------------------------------
    function _scenarios() internal {
        uint256 usdcNeeded = 1000 * 1e6;

        _scn_mint_requires_liquidityOrBalances(usdcNeeded);
        _scn_mint_zero_amount_reverts();
        _scn_mint_insufficient_usdc_reverts();

        uint256 mintId = _scn_mint_success();
        _scn_claim_before_finalization_reverts(mintId);
        _transition(1e6); // finalize epoch 1 at NAV 1.0 USDC/WSK
        _scn_mint_claim_success(mintId);

        _scn_redeem_zero_amount_reverts();
        _scn_redeem_insufficient_wsk_reverts();
        uint256 redeemId = _scn_redeem_success();
        _scn_redeem_claim_before_finalization_reverts(redeemId);

        _transition(1e6); // finalize epoch 2
        _scn_redeem_claim_success(redeemId);

        _scn_double_claim_reverts(mintId);
        _scn_claim_unknown_reverts();
        _scn_batch_mixed_and_duplicate();
        _scn_zero_settlement_reverts();
        _scn_wind_down_and_block_new();
    }

    // ------------------------------------------------------------------
    // Mint scenarios
    // ------------------------------------------------------------------
    function _ensureUserUsdc(uint256 amount) internal {
        if (usdc.balanceOf(deployer) < amount) {
            vm.startBroadcast(deployerKey);
            usdc.mint(deployer, amount);
            vm.stopBroadcast();
        }
    }

    function _scn_mint_requires_liquidityOrBalances(uint256 amount) internal {
        _ensureUserUsdc(amount);
        _check("mint: user has USDC", usdc.balanceOf(deployer) >= amount);
    }

    function _scn_mint_zero_amount_reverts() internal {
        (bool ok,) = _tryDeployer(abi.encodeCall(WellstakeVault.requestMint, (0)));
        _check("mint: zero amount reverts", !ok);
    }

    function _scn_mint_insufficient_usdc_reverts() internal {
        uint256 huge = usdc.balanceOf(deployer) + 1_000_000 * 1e6;
        vm.prank(deployer);
        usdc.approve(address(vault), type(uint256).max);
        (bool ok,) = _tryDeployer(abi.encodeCall(WellstakeVault.requestMint, (huge)));
        _check("mint: insufficient USDC reverts", !ok);
    }

    function _scn_mint_success() internal returns (uint256 id) {
        uint256 amount = 100 * 1e6;
        vm.startBroadcast(deployerKey);
        usdc.approve(address(vault), type(uint256).max);
        id = vault.requestMint(amount);
        vm.stopBroadcast();
        _check("mint: request created", id != 0);
        _check("mint: NFT minted to owner", nft.ownerOf(id) == deployer);
        _check("mint: pending USDC escrowed", usdc.balanceOf(address(vault)) >= amount);
    }

    function _scn_claim_before_finalization_reverts(uint256 id) internal {
        (bool ok,) = _tryAnyone(abi.encodeCall(WellstakeVault.claim, (id)));
        _check("mint: claim before finalization reverts", !ok);
    }

    function _scn_mint_claim_success(uint256 id) internal {
        uint256 balBefore = wsk.balanceOf(deployer);
        vm.startBroadcast(deployerKey);
        vault.claim(id);
        vm.stopBroadcast();
        uint256 gained = wsk.balanceOf(deployer) - balBefore;
        _check("mint: claim mints WSK", gained == 100 * 1e6);
        _check("mint: NFT burned after claim", !_nftExists(id));
    }

    // ------------------------------------------------------------------
    // Redeem scenarios
    // ------------------------------------------------------------------
    function _scn_redeem_zero_amount_reverts() internal {
        vm.prank(deployer);
        wsk.approve(address(vault), type(uint256).max);
        (bool ok,) = _tryDeployer(abi.encodeCall(WellstakeVault.requestRedeem, (0)));
        _check("redeem: zero amount reverts", !ok);
    }

    function _scn_redeem_insufficient_wsk_reverts() internal {
        uint256 huge = wsk.balanceOf(deployer) + 1_000_000 * 1e6;
        (bool ok,) = _tryDeployer(abi.encodeCall(WellstakeVault.requestRedeem, (huge)));
        _check("redeem: insufficient WSK reverts", !ok);
    }

    function _scn_redeem_success() internal returns (uint256 id) {
        vm.startBroadcast(deployerKey);
        wsk.approve(address(vault), type(uint256).max);
        id = vault.requestRedeem(50 * 1e6);
        vm.stopBroadcast();
        _check("redeem: request created", id != 0);
        _check("redeem: fee taken in WSK", wsk.balanceOf(vault.feeWallet()) > 0);
    }

    function _scn_redeem_claim_before_finalization_reverts(uint256 id) internal {
        (bool ok,) = _tryAnyone(abi.encodeCall(WellstakeVault.claim, (id)));
        _check("redeem: claim before finalization reverts", !ok);
    }

    function _scn_redeem_claim_success(uint256 id) internal {
        uint256 usdcBefore = usdc.balanceOf(deployer);
        vm.startBroadcast(deployerKey);
        vault.claim(id);
        vm.stopBroadcast();
        _check("redeem: USDC paid to owner", usdc.balanceOf(deployer) > usdcBefore);
        _check("redeem: NFT burned after claim", !_nftExists(id));
    }

    // ------------------------------------------------------------------
    // Cross-cutting scenarios
    // ------------------------------------------------------------------
    function _scn_double_claim_reverts(uint256 id) internal {
        (bool ok,) = _tryAnyone(abi.encodeCall(WellstakeVault.claim, (id)));
        _check("claim: double claim reverts", !ok);
    }

    function _scn_claim_unknown_reverts() internal {
        (bool ok,) = _tryAnyone(abi.encodeCall(WellstakeVault.claim, (999_999)));
        _check("claim: unknown request reverts", !ok);
    }

    function _scn_batch_mixed_and_duplicate() internal {
        // Create two mint requests in the current epoch and finalize it.
        uint256 a = _requestMintSimple(10 * 1e6);
        uint256 b = _requestMintSimple(20 * 1e6);
        _transition(1e6);

        uint256[] memory dup = new uint256[](2);
        dup[0] = a;
        dup[1] = a;
        (bool dupOk,) = _tryDeployer(abi.encodeCall(WellstakeVault.claimMany, (dup)));
        _check("batch: duplicate ids revert", !dupOk);

        uint256[] memory ids = new uint256[](2);
        ids[0] = a;
        ids[1] = b;
        vm.startBroadcast(deployerKey);
        vault.claimMany(ids);
        vm.stopBroadcast();
        _check("batch: mixed ids settle", !_nftExists(a) && !_nftExists(b));

        uint256[] memory empty = new uint256[](0);
        (bool emptyOk,) = _tryDeployer(abi.encodeCall(WellstakeVault.claimMany, (empty)));
        _check("batch: empty batch reverts", !emptyOk);
    }

    function _scn_zero_settlement_reverts() internal {
        // Tiny mint request, then finalize at a huge NAV so floor() == 0.
        uint256 id = _requestMintSimple(1); // 1 micro-USDC
        _transition(1e12); // NAV = 1,000,000 USDC/WSK => settles to 0

        (bool ok,) = _tryAnyone(abi.encodeCall(WellstakeVault.claim, (id)));
        _check("settlement: zero-output claim reverts", !ok);
        _check("settlement: tiny request NFT preserved", _nftExists(id));
    }

    function _scn_wind_down_and_block_new() internal {
        vm.startBroadcast(managerKey);
        vault.pause(1e6);
        vm.stopBroadcast();
        _check("winddown: irreversible flag set", vault.woundDown());

        (bool mintOk,) = _tryDeployer(abi.encodeCall(WellstakeVault.requestMint, (10 * 1e6)));
        _check("winddown: new mint blocked", !mintOk);

        (bool redeemOk,) = _tryDeployer(abi.encodeCall(WellstakeVault.requestRedeem, (1 * 1e6)));
        _check("winddown: new redeem blocked", !redeemOk);

        vm.prank(manager);
        (bool transOk,) = address(vault).call(abi.encodeCall(WellstakeVault.transitionEpoch, (1e6)));
        _check("winddown: transition blocked", !transOk);

        // WSK transfers still work.
        vm.startBroadcast(deployerKey);
        wsk.transfer(address(0xBEEF), 1 * 1e6);
        vm.stopBroadcast();
        _check("winddown: WSK transfer still works", wsk.balanceOf(address(0xBEEF)) == 1 * 1e6);
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------
    function _requestMintSimple(uint256 amount) internal returns (uint256 id) {
        _ensureUserUsdc(amount);
        vm.startBroadcast(deployerKey);
        usdc.approve(address(vault), type(uint256).max);
        id = vault.requestMint(amount);
        vm.stopBroadcast();
    }

    function _transition(uint256 nav) internal {
        vm.startBroadcast(managerKey);
        vault.transitionEpoch(nav);
        vm.stopBroadcast();
    }

    function _tryDeployer(bytes memory data) internal returns (bool ok, bytes memory ret) {
        vm.prank(deployer);
        (ok, ret) = address(vault).call(data);
    }

    function _tryAnyone(bytes memory data) internal returns (bool ok, bytes memory ret) {
        (ok, ret) = address(vault).call(data);
    }

    function _nftExists(uint256 id) internal view returns (bool) {
        try nft.ownerOf(id) returns (address) {
            return true;
        } catch {
            return false;
        }
    }

    function _check(string memory label, bool condition) internal {
        if (condition) {
            pass++;
            console.log(string.concat("[PASS] ", label));
        } else {
            fail++;
            console.log(string.concat("[FAIL] ", label));
        }
    }

    receive() external payable {}
}
