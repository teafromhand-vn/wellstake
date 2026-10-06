// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @dev Deployable 6-decimal quote token ("testQuoteToken", symbol "QT") used as a settlement
///      asset for test deployments. Anyone may mint for testing purposes.
contract TestQuoteToken is ERC20 {
    constructor() ERC20("testQuoteToken", "QT") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
