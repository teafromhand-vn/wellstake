// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {LiquidWallet} from "../src/LiquidWallet.sol";
import {WellstakeVault} from "../src/WellstakeVault.sol";
import {WellstakeToken} from "../src/WellstakeToken.sol";
import {PendingRequestNFT} from "../src/PendingRequestNFT.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";

abstract contract WellstakeTestBase is Test {
    uint256 internal constant INITIAL_NAV = 38_462;
    uint256 internal constant ONE = 1e6;
    uint256 internal constant FEE_BPS = 50;
    uint256 internal constant BPS_DENOMINATOR = 10_000;

    MockUSDC internal usdc;
    LiquidWallet internal liquid;
    WellstakeVault internal vault;
    WellstakeToken internal wsk;
    PendingRequestNFT internal nft;

    address internal manager = makeAddr("manager");
    address internal vaultWallet = makeAddr("vaultWallet");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    function setUp() public virtual {
        usdc = new MockUSDC();
        liquid = new LiquidWallet(address(usdc), manager, vaultWallet, "Wellstake", "WSK");
        vault = new WellstakeVault(address(usdc), address(liquid), vaultWallet);
        vm.prank(manager);
        liquid.setVault(address(vault));

        wsk = liquid.wsk();
        nft = liquid.pendingNFT();

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
        usdc.approve(address(liquid), amount);
    }

    function _requestMint(address user, uint256 usdcAmount) internal returns (uint256 id) {
        _fundUSDC(user, usdcAmount);
        _approveUSDC(user, usdcAmount);
        vm.prank(user);
        id = liquid.requestMint(usdcAmount);
    }

    function _requestRedeem(address user, uint256 grossWsk) internal returns (uint256 id) {
        vm.prank(user);
        wsk.approve(address(liquid), type(uint256).max);
        vm.prank(user);
        id = liquid.requestRedeem(grossWsk);
    }

    function _setNav(uint256 nav) internal {
        vm.prank(manager);
        liquid.setNav(nav);
    }

    function _finalizeEpoch(uint256 nav) internal {
        vm.prank(manager);
        liquid.finalizeEpoch(nav);
    }

    /// @dev Give `user` some WSK via a mint. Returns the actual WSK amount received.
    ///      The request's epoch must be finalized before it can be claimed.
    function _giveWSK(address user, uint256 usdcAmount)
        internal
        returns (uint256 id, uint256 wskAmount)
    {
        id = _requestMint(user, usdcAmount);
        // Finalize the open epoch so the request becomes claimable.
        _finalizeEpoch(liquid.totalNav());
        uint256 before = wsk.balanceOf(user);
        vm.prank(user);
        liquid.claim(id);
        wskAmount = wsk.balanceOf(user) - before;
        vm.prank(user);
        wsk.approve(address(liquid), type(uint256).max);
    }

    function _usdcToLiquid(uint256 amount) internal {
        usdc.mint(address(liquid), amount);
    }
}
