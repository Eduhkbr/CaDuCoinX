// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title TestERC20
 * @dev Token ERC20 simples para testes, simulando o ETH (18 decimais).
 *
 * Nota: O ETH possui 18 decimais por padrão, portanto não é necessário sobrescrever a função decimals().
 */
contract TestERC20 is ERC20 {

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        // Para simular o ETH, utilizamos os 18 decimais padrão do ERC20 do OpenZeppelin.
    }

    /**
     * @dev Função de mint para teste.
     * Permite cunhar uma quantidade especificada de tokens para o endereço 'to'.
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}