// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./CaDuCoinXToken.sol";

/**
@title CaDuCoinXTokenProxy
@dev Proxy para o contrato CaDuCoinXToken, utilizando o padrão ERC1967.
*/
contract CaDuCoinXTokenProxy is ERC1967Proxy{

    /**
    @notice Construtor que inicializa o proxy com o endereço da lógica e dados de inicialização.
    @param _logic Endereço do contrato de lógica (implementação).
    @param _data Dados de inicialização para o contrato de lógica.
    */
    constructor(
        address _logic, 
        bytes memory _data
    ) 
        ERC1967Proxy(_logic, _data)
    {}

    /**
    @dev Rejeita recebimento de Ether.
    */
    receive() external payable {
        revert("Contract does not accept Ether");
    }
}