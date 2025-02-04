// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol"; 
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "./GameToken.sol";

/**
 * @title CaDuCoinXToken
 * @dev Token ERC-20 com funcionalidades de mint, burn, gamificação e marketplace.
 * Utiliza AccessControl para autorizar a função mint, permitindo que contratos específicos sejam minters.
 */
contract CaDuCoinXToken is Initializable, ERC20Upgradeable, OwnableUpgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable, PausableUpgradeable {
    uint256 public constant DECIMALS = 18;
    uint256 public constant MAX_SUPPLY = 21000000 * (10 ** DECIMALS);

    // Define o MINTER_ROLE utilizando AccessControl.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    GameToken public gameToken;

    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);

    /**
     * @notice Inicializa o token e configura AccessControl.
     * @param _owner Endereço do proprietário/admin do contrato.
     * @param name Nome do token.
     * @param symbol Símbolo do token.
     * @param _gameToken Endereço do contrato GameToken.
     */
    function initialize(address _owner, string memory name, string memory symbol, address _gameToken) public initializer {
        __ERC20_init(name, symbol);
        __Ownable_init(_owner);
        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        __Pausable_init();

        // Conceder papéis utilizando _grantRole
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(MINTER_ROLE, _owner);

        gameToken = GameToken(_gameToken);
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

    // Outras funções (burn, levelUp, getPlayerData) continuam inalteradas.
    function burn(address from, uint256 amount) public onlyOwner whenNotPaused {
        require(balanceOf(from) >= amount, "Insufficient balance to burn");
        _burn(from, amount);
        emit Burned(from, amount);
    }

    function levelUp(address player) public onlyOwner whenNotPaused {
        gameToken.levelUp(player);
    }

    function getPlayerData(address player) public view returns (GameToken.PlayerData memory) {
        return gameToken.getPlayerData(player);
    }
}
