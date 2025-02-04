// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @title TestNFT
 * @dev Contrato ERC721 simples para testes.
 */
contract TestNFT is ERC721 {
    uint256 public nextTokenId;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    /**
     * @dev Função de mint para teste.
     */
    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}