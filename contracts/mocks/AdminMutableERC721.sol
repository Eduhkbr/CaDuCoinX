// SPDX-License-Identifier: MIT
pragma solidity ^0.8.38;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract AdminMutableERC721 is ERC721 {
    address public immutable administrator;

    constructor() ERC721("Admin Mutable NFT", "AMNFT") {
        administrator = msg.sender;
    }

    function mint(address to, uint256 tokenId) external {
        require(msg.sender == administrator, "Not administrator");
        _safeMint(to, tokenId);
    }

    function adminTransfer(address from, address to, uint256 tokenId) external {
        require(msg.sender == administrator, "Not administrator");
        _transfer(from, to, tokenId);
    }

    function adminBurn(uint256 tokenId) external {
        require(msg.sender == administrator, "Not administrator");
        _burn(tokenId);
    }
}
