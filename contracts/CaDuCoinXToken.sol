// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/**
 * @title CaDuCoinXToken
 * @dev Token ERC-20 com funcionalidades de mint, burn, gamificação, compra e venda por ETH e limite de saque.
 */
contract CaDuCoinXToken is Initializable, ERC20Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable, PausableUpgradeable {
    uint256 public constant DECIMALS = 18;
    uint256 public constant MAX_SUPPLY = 21000000 * (10 ** DECIMALS);

    // Preço de compra (em wei) para 1 token (1 token = 10**18 unidades)
    uint256 public salePrice; // Ex: 0.0000033 ETH (3300000000000 wei)
    bool public saleActive;   // Flag para ativar ou pausar a compra de tokens

    // Preço de venda (em wei) para 1 token
    uint256 public sellPrice;

    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);
    event LevelUp(address indexed player, uint256 newLevel);
    event TokensPurchased(address indexed buyer, uint256 tokenAmount);
    event TokensSold(address indexed seller, uint256 tokenAmount, uint256 ethAmount);
    event SalePriceUpdated(uint256 newSalePrice);
    event SaleStatusUpdated(bool saleActive);
    event Withdraw(uint256 amount);

    // Estrutura para gamificação com dados do jogador
    struct PlayerData {
        uint256 level;
    }
    // Mapeia endereços dos jogadores para seus dados de gamificação
    mapping(address => PlayerData) public players;

    /**
     * @notice Inicializa o token e configura o contrato.
     * @param _owner Endereço do proprietário/admin do contrato.
     * @param name Nome do token.
     * @param symbol Símbolo do token.
     *
     * O preço inicial de compra é fixado em 0.0000033 ETH (3300000000000 wei).
     * O preço de venda é definido como 98% do preço de compra.
     */
    function initialize(address _owner, string memory name, string memory symbol) public initializer {
        __ERC20_init(name, symbol);
        __Ownable_init(_owner);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        __Pausable_init();

        salePrice = 3300000000000;                // 0.0000033 ETH em wei
        sellPrice = salePrice * 98 / 100;           // 98% de 0.0000033 ETH
        saleActive = true;                        // Compra ativa por padrão
    }

    /**
     * @dev Função requerida para upgrades pelo padrão UUPS.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @notice Emite tokens para um endereço.
     * @param to Endereço de destino.
     * @param amount Quantidade de tokens a serem mintados (valor interno com 18 decimais).
     */
    function mint(address to, uint256 amount) public whenNotPaused onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds maximum supply");
        _mint(to, amount);
        emit Minted(to, amount);
    }

    /**
     * @notice Queima tokens do endereço que chama a função.
     * @param amount Quantidade de tokens a serem queimados.
     */
    function burn(uint256 amount) public whenNotPaused {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance to burn");
        _burn(msg.sender, amount);
        emit Burned(msg.sender, amount);
    }

    /**
     * @notice Incrementa o nível do jogador.
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
     * @return Dados do jogador.
     */
    function getPlayerData(address player) public view returns (PlayerData memory) {
        return players[player];
    }

    /**
     * @notice Permite a compra de tokens utilizando ETH.
     *
     * Converte o ETH enviado em tokens através do cálculo:
     *     mintedAmount = (msg.value * 10 ** DECIMALS) / salePrice.
     */
    function purchaseTokens() external payable whenNotPaused nonReentrant {
        require(saleActive, "Sale is not active");
        require(msg.value > 0, "No ETH sent");

        uint256 mintedAmount = msg.value * (10 ** DECIMALS) / salePrice;
        require(totalSupply() + mintedAmount <= MAX_SUPPLY, "Exceeds maximum supply");

        _mint(msg.sender, mintedAmount);
        emit Minted(msg.sender, mintedAmount);
        emit TokensPurchased(msg.sender, mintedAmount);
    }

    /**
     * @notice Permite que os usuários vendam seus tokens por ETH.
     *
     * Calcula o valor em ETH a ser recebido por:
     *     ethAmount = (tokenAmount * sellPrice) / (10 ** DECIMALS).
     *
     * Os tokens vendidos são queimados.
     * @param tokenAmount Quantidade de tokens a serem vendidos.
     */
    function sellTokens(uint256 tokenAmount) external whenNotPaused nonReentrant {
        require(tokenAmount > 0, "Token amount must be greater than zero");
        require(balanceOf(msg.sender) >= tokenAmount, "Insufficient token balance");

        uint256 ethAmount = tokenAmount * sellPrice / (10 ** DECIMALS);
        require(address(this).balance >= ethAmount, "Contract has insufficient ETH");

        _burn(msg.sender, tokenAmount);
        (bool sent, ) = msg.sender.call{value: ethAmount}("");
        require(sent, "ETH transfer failed");

        emit TokensSold(msg.sender, tokenAmount, ethAmount);
    }

    /**
     * @notice Atualiza o preço de compra do token e ajusta o preço de venda para 98% do novo salePrice.
     * @param _newSalePrice Novo preço de compra em wei para 1 token.
     */
    function updateSalePrice(uint256 _newSalePrice) external onlyOwner {
        require(_newSalePrice > 0, "Sale price must be greater than zero");
        salePrice = _newSalePrice;
        sellPrice = _newSalePrice * 98 / 100;
        emit SalePriceUpdated(_newSalePrice);
    }

    /**
     * @notice Ativa ou desativa a compra de tokens.
     * @param _saleActive true para ativar ou false para desativar.
     */
    function setSaleActive(bool _saleActive) external onlyOwner {
        saleActive = _saleActive;
        emit SaleStatusUpdated(_saleActive);
    }

    /**
     * @notice Permite que o owner retire o ETH acumulado que exceda a reserva necessária.
     *
     * A reserva necessária é calculada como:
     *    requiredBalance = (totalSupply() * sellPrice) / (10 ** DECIMALS).
     */
    function withdraw() external onlyOwner nonReentrant {
        uint256 totalTokenSupply = totalSupply();
        uint256 requiredBalance = totalTokenSupply * sellPrice / (10 ** DECIMALS);
        uint256 contractBalance = address(this).balance;

        require(contractBalance > requiredBalance, "No excess funds to withdraw");
        uint256 withdrawable = contractBalance - requiredBalance;

        (bool sent, ) = msg.sender.call{value: withdrawable}("");
        require(sent, "Withdraw failed");

        emit Withdraw(withdrawable);
    }
}