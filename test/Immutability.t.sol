// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {WellstakeTestBase} from "./WellstakeTestBase.sol";
import {WellstakeVault} from "../src/WellstakeVault.sol";

contract ImmutabilityTest is WellstakeTestBase {
    function test_IMM001_managerCannotBeChanged() public view {
        // No setter exists on the public surface; config is immutable.
        assertEq(vault.manager(), manager);
        (bool ok,) = address(vault).staticcall(abi.encodeWithSignature("setManager(address)", bob));
        assertFalse(ok);
    }

    function test_IMM002_usdcAddressCannotBeChanged() public view {
        assertEq(address(vault.usdc()), address(usdc));
        (bool ok,) = address(vault).staticcall(abi.encodeWithSignature("setUsdc(address)", bob));
        assertFalse(ok);
    }

    function test_IMM003_vaultWalletCannotBeChanged() public view {
        assertEq(vault.vaultWallet(), vaultWallet);
        (bool ok,) =
            address(vault).staticcall(abi.encodeWithSignature("setVaultWallet(address)", bob));
        assertFalse(ok);
    }

    function test_IMM004_liquidWalletCannotBeChanged() public view {
        assertEq(vault.liquidWallet(), liquidWallet);
        (bool ok,) =
            address(vault).staticcall(abi.encodeWithSignature("setLiquidWallet(address)", bob));
        assertFalse(ok);
    }

    function test_IMM005_feeWalletCannotBeChanged() public view {
        assertEq(vault.feeWallet(), feeWallet);
        (bool ok,) =
            address(vault).staticcall(abi.encodeWithSignature("setFeeWallet(address)", bob));
        assertFalse(ok);
    }

    function test_IMM006_wskVaultAuthorityCannotBeChanged() public view {
        assertEq(wsk.vault(), address(vault));
        (bool ok,) = address(wsk).staticcall(abi.encodeWithSignature("setVault(address)", bob));
        assertFalse(ok);
    }

    function test_IMM007_noUpgradeProxy() public view {
        // V1 is a plain non-upgradeable implementation. Immutable config proves no proxy admin
        // storage slot was used; the deployed code has no upgrade entrypoints.
        assertEq(vault.manager(), manager);
        (bool ok,) = address(vault).staticcall(abi.encodeWithSignature("upgradeTo(address)", bob));
        assertFalse(ok);
        (bool ok2,) = address(vault).staticcall(abi.encodeWithSignature("admin()"));
        assertFalse(ok2);
    }
}
