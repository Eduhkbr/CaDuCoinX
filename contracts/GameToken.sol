// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
@title GameToken
@dev Contrato de gamificação que gerencia os dados dos jogadores.
*/
contract GameToken is Initializable, OwnableUpgradeable {
    struct PlayerData {
        uint256 level;
    }

    mapping(address => PlayerData) public players;

    event LevelUp(address indexed player, uint256 newLevel);

    /**
    @notice Inicializa o contrato definindo o proprietário.
    @param _owner Endereço do proprietário do contrato.
    */
    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
        _transferOwnership(_owner);
    }

    /**
    @notice Incrementa o nível do jogador.
    Somente o owner pode chamar essa função.
    @param player Endereço do jogador.
    */
    function levelUp(address player) external onlyOwner {
        require(player != address(0), "Invalid player address");
        players[player].level += 1;
        emit LevelUp(player, players[player].level);
    }

    /**
    @notice Retorna os dados de gamificação do jogador.
    @param player Endereço do jogador.
    */
    function getPlayerData(address player) external view returns (PlayerData memory) {
        return players[player];
    }
}
