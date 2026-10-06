// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {WellstakeVault} from "../src/WellstakeVault.sol";
import {WellstakeToken} from "../src/WellstakeToken.sol";
import {PendingRequestNFT} from "../src/PendingRequestNFT.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";

abstract contract WellstakeTestBase is Test {
    uint256 internal constant INITIAL_NAV = 38_462;
    uint256 internal constant ONE_USDC = 1e6;
    uint256 internal constant ONE_WSK = 1e6;
    uint256 internal constant FEE_BPS = 50;
    uint256 internal constant BPS_DENOMINATOR = 10_000;

    MockUSDC internal usdc;
    WellstakeVault internal vault;
    WellstakeToken internal wsk;
    PendingRequestNFT internal nft;

    address internal manager = makeAddr("manager");
    address internal vaultWallet = makeAddr("vaultWallet");
    address internal liquidWallet = makeAddr("liquidWallet");
    address internal feeWallet = makeAddr("feeWallet");

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    function setUp() public virtual {
        usdc = new MockUSDC();
        vault = new WellstakeVault(address(usdc), manager, vaultWallet, liquidWallet, feeWallet);
        wsk = vault.wsk();
        nft = vault.pendingNFT();

        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(carol, 100 ether);
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    function _fundUSDC(address user, uint256 amount) internal {
        usdc.mint(user, amount);
    }

    function _approveUSDC(address user, uint256 amount) internal {
        vm.prank(user);
        usdc.approve(address(vault), amount);
    }

    function _requestMint(address user, uint256 usdcAmount) internal returns (uint256 id) {
        vm.prank(user);
        id = vault.requestMint(usdcAmount);
    }

    /// @dev Fund `user` with USDC, approve and create a mint request.
    function _mint(address user, uint256 usdcAmount) internal returns (uint256 id) {
        _fundUSDC(user, usdcAmount);
        _approveUSDC(user, usdcAmount);
        return _requestMint(user, usdcAmount);
    }

    function _requestRedeem(address user, uint256 grossWsk) internal returns (uint256 id) {
        vm.prank(user);
        wsk.approve(address(vault), type(uint256).max);
        vm.prank(user);
        id = vault.requestRedeem(grossWsk);
    }

    /// @dev Fund liquidWallet with USDC and approve the Vault to pull it.
    function _fundLiquid(uint256 amount) internal {
        usdc.mint(liquidWallet, amount);
        vm.prank(liquidWallet);
        usdc.approve(address(vault), type(uint256).max);
    }

    function _transition(uint256 navPerToken) internal returns (uint256 finalizedEpoch) {
        finalizedEpoch = vault.currentEpoch();
        vm.prank(manager);
        vault.transitionEpoch(navPerToken);
    }

    function _windDown(uint256 finalNav) internal {
        vm.prank(manager);
        vault.pause(finalNav);
    }

    /// @dev Give `user` `amount` WSK by minting at NAV = 1e6 (1 USDC == 1 WSK) then claiming.
    ///      This finalizes Epoch 1 and makes Epoch 2 active.
    function _giveWSK(address user, uint256 amount) internal returns (uint256 requestId) {
        requestId = _mint(user, amount);
        _transition(ONE_USDC);
        vault.claim(requestId);

        vm.prank(user);
        wsk.approve(address(vault), type(uint256).max);
    }
}
