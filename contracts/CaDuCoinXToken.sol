// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol"; 
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/**
 * @title CaDuCoinXToken
 * @dev Token ERC-20 com funcionalidades integradas de mint, burn, e gamificação (níveis dos jogadores).
 * Utiliza AccessControl para autorizar a função mint.
 */
contract CaDuCoinXToken is Initializable, ERC20Upgradeable, OwnableUpgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable, PausableUpgradeable {
    uint256 public constant DECIMALS = 18;
    uint256 public constant MAX_SUPPLY = 21000000 * (10 ** DECIMALS);

    // Define o papel de minter utilizando AccessControl.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Estrutura de dados para gerenciar a gamificação.
    struct PlayerData {
        uint256 level;
        // Você pode adicionar outros dados, como experiência, conquistas, etc.
    }

    // Mapeia os endereços dos jogadores a seus dados de gamificação.
    mapping(address => PlayerData) public players;

    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);
    event LevelUp(address indexed player, uint256 newLevel);

    /**
     * @notice Inicializa o token e configura o AccessControl.
     * @param _owner Endereço do proprietário/admin do contrato.
     * @param name Nome do token.
     * @param symbol Símbolo do token.
     */
    function initialize(address _owner, string memory name, string memory symbol) public initializer {
        __ERC20_init(name, symbol);
        __Ownable_init(_owner);
        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        __Pausable_init();

        // Concede papéis iniciais ao _owner.
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(MINTER_ROLE, _owner);
    }

    /**
     * @dev Função requerida pelo padrão UUPS para autorizar upgrade.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @notice Emite (mint) tokens para um endereço.
     * @param to Endereço onde os tokens serão mintados.
     * @param amount Quantidade de tokens a serem mintados.
     */
    function mint(address to, uint256 amount) public whenNotPaused {
        require(hasRole(MINTER_ROLE, msg.sender), "Not authorized to mint");
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds maximum supply");
        _mint(to, amount);
        emit Minted(to, amount);
    }

    /**
     * @notice Queima (burn) tokens do endereço.
     * @param from Endereço do qual os tokens serão queimados.
     * @param amount Quantidade de tokens a serem queimados.
     */
    function burn(address from, uint256 amount) public onlyOwner whenNotPaused {
        require(balanceOf(from) >= amount, "Insufficient balance to burn");
        _burn(from, amount);
        emit Burned(from, amount);
    }

    /**
     * @notice Incrementa o nível do jogador.
     * Somente o owner pode chamar essa função.
     * @param player Endereço do jogador.
     */
    function levelUp(address player) public onlyOwner whenNotPaused {
        require(player != address(0), "Invalid player address");
        players[player].level += 1;
        emit LevelUp(player, players[player].level);
    }

    /**
     * @notice Retorna os dados de gamificação do jogador.
     * @param player Endereço do jogador.
     */
    function getPlayerData(address player) public view returns (PlayerData memory) {
        return players[player];
    }
}
