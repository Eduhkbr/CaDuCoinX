// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface INFTMarketplace {
    function buyNFT(address nftContract, uint256 tokenId) external;
}

contract ReentrantNFTBuyer is IERC721Receiver {
    address public immutable marketplace;
    bool public reentryAttempted;
    bool public reentrySucceeded;

    constructor(address marketplaceAddress) {
        marketplace = marketplaceAddress;
    }

    function buy(address nftContract, uint256 tokenId) external {
        INFTMarketplace(marketplace).buyNFT(nftContract, tokenId);
    }

    function approvePaymentToken(address token, uint256 amount) external {
        IERC20(token).approve(marketplace, amount);
    }

    function onERC721Received(address, address, uint256 tokenId, bytes calldata) external returns (bytes4) {
        reentryAttempted = true;
        try INFTMarketplace(marketplace).buyNFT(msg.sender, tokenId) {
            reentrySucceeded = true;
        } catch {}
        return IERC721Receiver.onERC721Received.selector;
    }
}
