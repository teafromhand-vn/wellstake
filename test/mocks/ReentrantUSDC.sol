// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @dev USDC stand-in that can invoke a reentrant call during any transfer, to prove the Vault
///      cannot be exploited through malicious token callbacks.
contract ReentrantUSDC is ERC20 {
    address public target;
    bytes public payload;
    bool public armed;
    bool public bubbleUp = true;
    bool public attackSucceeded;
    uint256 public attackCount;

    constructor() ERC20("USD Coin", "USDC") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function setBubbleUp(bool value) external {
        bubbleUp = value;
    }

    /// @notice Arm a one-shot reentrant call executed on the next transfer between two accounts.
    function setAttack(address target_, bytes calldata payload_) external {
        target = target_;
        payload = payload_;
        armed = true;
    }

    function _update(address from, address to, uint256 value) internal override {
        if (armed && from != address(0) && to != address(0)) {
            armed = false;
            attackCount++;
            (bool ok, bytes memory ret) = target.call(payload);
            attackSucceeded = ok;
            if (!ok && bubbleUp) {
                assembly {
                    revert(add(ret, 32), mload(ret))
                }
            }
        }
        super._update(from, to, value);
    }
}
