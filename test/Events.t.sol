// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {WellstakeTestBase} from "./WellstakeTestBase.sol";
import {WellstakeVault} from "../src/WellstakeVault.sol";

contract EventsTest is WellstakeTestBase {
    function test_EVENT001_mintRequested() public {
        uint256 amount = 100 * ONE_USDC;
        _fundUSDC(alice, amount);
        _approveUSDC(alice, amount);

        vm.expectEmit(true, true, true, true);
        emit WellstakeVault.MintRequested(1, alice, amount, 1);

        vm.prank(alice);
        vault.requestMint(amount);
    }

    function test_EVENT002_redeemRequested() public {
        _giveWSK(alice, 1000 * ONE_WSK);
        uint256 gross = 100 * ONE_WSK;
        uint256 fee = gross * FEE_BPS / BPS_DENOMINATOR;

        vm.expectEmit(true, true, false, true);
        emit WellstakeVault.RedeemRequested(2, alice, gross, fee, 2);

        vm.prank(alice);
        vault.requestRedeem(gross);
    }

    function test_EVENT003_epochTransitioned() public {
        uint256 endBlock = block.number + 3;
        vm.roll(endBlock);

        vm.expectEmit(true, false, false, true);
        emit WellstakeVault.EpochTransitioned(1, ONE_USDC, endBlock);

        vm.prank(manager);
        vault.transitionEpoch(ONE_USDC);
    }

    function test_EVENT004_mintClaimed() public {
        uint256 id = _mint(alice, 100 * ONE_USDC);
        _transition(ONE_USDC);

        vm.expectEmit(true, true, false, true);
        emit WellstakeVault.MintClaimed(id, alice, 100 * ONE_WSK);

        vault.claim(id);
    }

    function test_EVENT005_redeemClaimed() public {
        _giveWSK(alice, 1000 * ONE_WSK);
        uint256 gross = 100 * ONE_WSK;
        uint256 net = gross - gross * FEE_BPS / BPS_DENOMINATOR;
        uint256 id = _requestRedeem(alice, gross);
        _transition(ONE_USDC);
        _fundLiquid(1000 * ONE_USDC);

        vm.expectEmit(true, true, false, true);
        emit WellstakeVault.RedeemClaimed(id, alice, net, net);

        vault.claim(id);
    }
}
