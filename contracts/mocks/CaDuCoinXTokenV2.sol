// SPDX-License-Identifier: MIT
pragma solidity ^0.8.38;

import "../CaDuCoinXToken.sol";

contract CaDuCoinXTokenV2 is CaDuCoinXToken {
    function version() external pure returns (uint256) {
        return 2;
    }
}
