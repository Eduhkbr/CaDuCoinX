// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./GameToken.sol";

/**
@title CaDuCoinXToken
@dev Token ERC-20 para microtransações e integração com o ecossistema unificado.
Funcionalidades: mint, burn, marketplace (itens e NFTs) e integração de gamificação.
*/
contract CaDuCoinXToken is Initializable, ERC20Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable, PausableUpgradeable {
    uint256 public constant DECIMALS = 18;
    uint256 public constant MAX_SUPPLY = 21000000 * (10 ** DECIMALS);

    // Integração com gamificação: a lógica de levelUp é delegada ao GameToken.
    GameToken public gameToken;

    // Estrutura para itens de marketplace (pode ser expandida para NFTs futuros, etc.)
    struct Item {
        uint256 id;
        string name;
        uint256 price;
    }

    mapping(uint256 => Item) public items;
    uint256 public nextItemId;

    // Eventos para auditoria e monitoramento de operações críticas.
    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);
    event ItemPurchased(address indexed buyer, uint256 itemId, uint256 price);
    event NFTPurchased(address indexed buyer, address nftContract, uint256 tokenId, uint256 price);
    
    /**
    * @notice Inicializa o token e vincula o GameToken para funcionalidades de gamificação.
    * @param _owner Endereço do proprietário (owner) do contrato.
    * @param name Nome do token.
    * @param symbol Símbolo do token.
    * @param _gameToken Endereço do contrato GameToken.
    */
    function initialize(address _owner, string memory name, string memory symbol, address _gameToken) public initializer {
        __ERC20_init(name, symbol);
        __Ownable_init(_owner);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        __Pausable_init();

        _transferOwnership(_owner);
        gameToken = GameToken(_gameToken);
    }

    /**
    * @dev Função requerida pelo padrão UUPS para autorizar upgrade.
    */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
    * @notice Emite (mint) tokens para um endereço, respeitando o limite máximo de supply.
    */
    function mint(address to, uint256 amount) public onlyOwner whenNotPaused {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds maximum supply");
        _mint(to, amount);
        emit Minted(to, amount);
    }

    /**
    * @notice Queima (burn) tokens do endereço informado.
    */
    function burn(address from, uint256 amount) public onlyOwner whenNotPaused {
        require(balanceOf(from) >= amount, "Insufficient balance to burn");
        _burn(from, amount);
        emit Burned(from, amount);
    }

    /**
    * @notice Delegação para o GameToken realizar o levelUp do jogador.
    * @param player Endereço do jogador.
    */
    function levelUp(address player) public onlyOwner whenNotPaused {
        gameToken.levelUp(player);
    }

    /**
    * @notice Retorna os dados de gamificação de um jogador.
    * @param player Endereço do jogador.
    */
    function getPlayerData(address player) public view returns (GameToken.PlayerData memory) {
        return gameToken.getPlayerData(player);
    }

    /**
    * @notice Adiciona um item ao marketplace.
    * @param name Nome/descritivo do item.
    * @param price Preço do item em tokens (considera os decimais do token).
    */
    function addItem(string memory name, uint256 price) public onlyOwner whenNotPaused {
        items[nextItemId] = Item(nextItemId, name, price);
        nextItemId++;
    }

    /**
    * @notice Permite a compra de um item. Transfere tokens do comprador para o contrato.
    * @param itemId Identificador do item.
    */
    function purchaseItem(uint256 itemId) public whenNotPaused {
        Item memory item = items[itemId];
        require(item.price > 0, "Item does not exist");
        require(balanceOf(msg.sender) >= item.price, "Insufficient balance");
        
        // Transferência segura com verificação implícita pela função _transfer
        _transfer(msg.sender, address(this), item.price);
        emit ItemPurchased(msg.sender, itemId, item.price);
    }

    /**
    * @notice Compra um NFT utilizando tokens.
    * Transfere tokens do comprador, verifica a posse do NFT no contrato e efetua a transferência.
    * @param nftContract Endereço do contrato ERC721 do NFT.
    * @param tokenId ID do NFT.
    * @param price Preço do NFT (em tokens).
    */
    function purchaseNFT(address nftContract, uint256 tokenId, uint256 price) public whenNotPaused {
        require(balanceOf(msg.sender) >= price, "Insufficient balance");
        _transfer(msg.sender, address(this), price);
        
        // Valida se o contrato realmente possui o NFT
        require(IERC721(nftContract).ownerOf(tokenId) == address(this), "Contract does not own the NFT");

        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
        
        // Verifica se a transferência ocorreu corretamente
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "NFT transfer failed");
        emit NFTPurchased(msg.sender, nftContract, tokenId, price);
    }
}
