// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../CaDuCoinXNFTMarketplace.sol";

/// @custom:oz-upgrades-unsafe-allow missing-initializer
contract CaDuCoinXNFTMarketplaceV2 is CaDuCoinXNFTMarketplace {
    function version() external pure returns (uint256) {
        return 2;
    }
}
