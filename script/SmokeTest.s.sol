// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {LiquidWallet} from "../src/LiquidWallet.sol";
import {WellstakeVault} from "../src/WellstakeVault.sol";
import {WellstakeToken} from "../src/WellstakeToken.sol";
import {PendingRequestNFT} from "../src/PendingRequestNFT.sol";

/// @notice Live smoke test against an already-deployed Wellstake stack using a real ERC-20 USDC
///         (no minting). Env: PRIVATE_KEY (user), MANAGER_PRIVATE_KEY, RPC, LIQUID, VAULT, USDC.
contract SmokeTest is Script {
    uint256 internal userKey;
    uint256 internal managerKey;
    address internal user;
    address internal manager;

    LiquidWallet internal liquid;
    WellstakeVault internal vault;
    WellstakeToken internal wsk;
    PendingRequestNFT internal nft;
    IERC20 internal usdc;

    uint256 internal pass;
    uint256 internal fail;

    function run() external {
        userKey = vm.envUint("PRIVATE_KEY");
        managerKey = vm.envUint("MANAGER_PRIVATE_KEY");
        user = vm.addr(userKey);
        manager = vm.addr(managerKey);

        liquid = LiquidWallet(vm.envAddress("LIQUID"));
        vault = WellstakeVault(vm.envAddress("VAULT"));
        usdc = IERC20(vm.envAddress("USDC"));
        wsk = liquid.wsk();
        nft = liquid.pendingNFT();

        console.log("== Wellstake live smoke test ==");
        console.log("liquid ", address(liquid));
        console.log("vault  ", address(vault));
        console.log("user USDC", usdc.balanceOf(user));

        _scenarios();

        console.log("PASS", pass);
        console.log("FAIL", fail);
        if (fail != 0) revert("smoke test had failures");
    }

    function _scenarios() internal {
        uint256 bal = usdc.balanceOf(user);
        _scn("user has USDC for mint", bal >= 1e6);

        // --- Mint ---
        uint256 amount = bal / 4;
        vm.startBroadcast(userKey);
        usdc.approve(address(liquid), type(uint256).max);
        uint256 mintId = liquid.requestMint(amount);
        vm.stopBroadcast();
        _scn("mint: request created + NFT", nft.ownerOf(mintId) == user);
        _scn("mint: USDC held by liquid", usdc.balanceOf(address(liquid)) >= amount);

        // Manager sets NAV so rate reflects supply; keep rate = 1.0 for a predictable test.
        vm.startBroadcast(managerKey);
        liquid.setNav(wsk.totalSupply() > 0 ? liquid.totalNav() : amount);
        vm.stopBroadcast();

        uint256 wskBefore = wsk.balanceOf(user);
        vm.startBroadcast(userKey);
        liquid.claim(mintId);
        vm.stopBroadcast();
        uint256 minted = wsk.balanceOf(user) - wskBefore;
        _scn("mint: tWSK minted to owner", minted > 0);

        // --- Redeem ---
        uint256 gross = minted / 2;
        vm.startBroadcast(userKey);
        wsk.approve(address(liquid), type(uint256).max);
        uint256 redeemId = liquid.requestRedeem(gross);
        vm.stopBroadcast();
        _scn("redeem: request created + NFT", nft.ownerOf(redeemId) == user);
        _scn("redeem: fee to manager", wsk.balanceOf(manager) > 0);

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
