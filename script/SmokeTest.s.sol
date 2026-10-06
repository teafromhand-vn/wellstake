// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {LiquidWallet} from "../src/LiquidWallet.sol";
import {WellstakeVault} from "../src/WellstakeVault.sol";
import {WellstakeToken} from "../src/WellstakeToken.sol";
import {PendingRequestNFT} from "../src/PendingRequestNFT.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";

/// @notice Live smoke test against an already-deployed Wellstake stack.
/// @dev Env: PRIVATE_KEY (user/deployer), MANAGER_PRIVATE_KEY, LIQUID, VAULT, USDC.
contract SmokeTest is Script {
    uint256 internal constant OP_SEPOLIA_CHAIN_ID = 11155420;

    uint256 internal userKey;
    uint256 internal managerKey;
    address internal user;
    address internal manager;

    LiquidWallet internal liquid;
    WellstakeVault internal vault;
    WellstakeToken internal wsk;
    PendingRequestNFT internal nft;
    MockUSDC internal usdc;

    uint256 internal pass;
    uint256 internal fail;

    function run() external {
        if (block.chainid != OP_SEPOLIA_CHAIN_ID) revert("not OP Sepolia");

        userKey = vm.envUint("PRIVATE_KEY");
        managerKey = vm.envUint("MANAGER_PRIVATE_KEY");
        user = vm.addr(userKey);
        manager = vm.addr(managerKey);

        liquid = LiquidWallet(vm.envAddress("LIQUID"));
        vault = WellstakeVault(vm.envAddress("VAULT"));
        usdc = MockUSDC(vm.envAddress("USDC"));
        wsk = liquid.wsk();
        nft = liquid.pendingNFT();

        console.log("== Wellstake live smoke test ==");
        console.log("liquid ", address(liquid));
        console.log("vault  ", address(vault));

        _scenarios();

        console.log("PASS", pass);
        console.log("FAIL", fail);
        if (fail != 0) revert("smoke test had failures");
    }

    function _scenarios() internal {
        _ensureUserUsdc(1000 * 1e6);

        // --- Mint ---
        _scn("mint: zero amount reverts", _tryMint(0));
        _scn("mint: insufficient USDC reverts", _tryMint(usdc.balanceOf(user) + 1_000_000 * 1e6));

        vm.startBroadcast(userKey);
        usdc.approve(address(liquid), type(uint256).max);
        uint256 mintId = liquid.requestMint(100 * 1e6);
        vm.stopBroadcast();
        _scn("mint: request created + NFT", nft.ownerOf(mintId) == user);
        _scn("mint: USDC held by liquid", usdc.balanceOf(address(liquid)) >= 100 * 1e6);

        // Finalize NAV at 100e6 total for 100e6 supply -> rate 1.0 (as manager).
        vm.startBroadcast(managerKey);
        liquid.setNav(100 * 1e6);
        vm.stopBroadcast();

        vm.startBroadcast(userKey);
        liquid.claim(mintId);
        vm.stopBroadcast();
        _scn("mint: WSK minted to owner", wsk.balanceOf(user) >= 100 * 1e6);

        // --- Redeem ---
        vm.startBroadcast(userKey);
        wsk.approve(address(liquid), type(uint256).max);
        uint256 redeemId = liquid.requestRedeem(50 * 1e6);
        vm.stopBroadcast();
        _scn(
            "redeem: fee taken by manager",
            wsk.balanceOf(manager) > 0 && nft.ownerOf(redeemId) == user
        );

        uint256 usdcBefore = usdc.balanceOf(user);
        vm.startBroadcast(userKey);
        liquid.claim(redeemId);
        vm.stopBroadcast();
        _scn("redeem: USDC paid to owner", usdc.balanceOf(user) > usdcBefore);

        // --- Guards ---
        _scn("claim: double claim reverts", _tryClaim(mintId));
        _scn("claim: unknown request reverts", _tryClaim(999_999));

        // --- Vault link ---
        _scn("vault: linked", liquid.vault() == address(vault));
    }

    function _ensureUserUsdc(uint256 amount) internal {
        if (usdc.balanceOf(user) < amount) {
            vm.startBroadcast(userKey);
            usdc.mint(user, amount);
            vm.stopBroadcast();
        }
    }

    function _tryMint(uint256 amount) internal returns (bool reverted) {
        vm.prank(user);
        (bool ok,) = address(liquid).call(abi.encodeCall(LiquidWallet.requestMint, (amount)));
        return !ok;
    }

    function _tryClaim(uint256 id) internal returns (bool reverted) {
        vm.prank(user);
        (bool ok,) = address(liquid).call(abi.encodeCall(LiquidWallet.claim, (id)));
        return !ok;
    }

    function _scn(string memory label, bool good) internal {
        if (good) {
            pass++;
            console.log(string.concat("[PASS] ", label));
        } else {
            fail++;
            console.log(string.concat("[FAIL] ", label));
        }
    }

    receive() external payable {}
}
