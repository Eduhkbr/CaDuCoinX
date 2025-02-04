// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./CaDuCoinXToken.sol";

/**
 * @title CaDuCoinXSaleUSDC
 * @dev Permite a compra de tokens CaDuCoinX utilizando USDC.
 * 
 * Nota: 1 token = 0,0086 USDC.
 * Considerando que o USDC possui 6 decimais,
 * o preço deverá ser configurado como: 0,0086 * 1,000,000 = 8600.
 *
 * O comprador precisa aprovar o contrato para gastar USDC.
 */
contract CaDuCoinXSaleUSDC is Initializable, OwnableUpgradeable {
    // Instância do token que será vendido.
    CaDuCoinXToken public token;
    // Instância do contrato USDC (ERC20).
    IERC20 public usdc;
    // Preço por token em USDC (por exemplo: 1 token = 1 USDC; se USDC tiver 6 decimais, preço = 1_000_000).
    uint256 public tokenPrice;
    // Endereço onde os USDC pagos serão enviados (ex: treasury).
    address public treasury;

    // Eventos para auditoria.
    event TokensPurchased(address indexed buyer, uint256 tokenAmount, uint256 cost);
    event TokenPriceUpdated(uint256 newPrice);

    /**
     * @notice Inicializa o contrato de venda.
     * @param _token Endereço do contrato CaDuCoinXToken.
     * @param _usdc Endereço do contrato USDC.
     * @param _treasury Endereço que receberá os USDC.
     * @param _owner Endereço dono do contrato.
     */
    function initialize(
        address _token,
        address _usdc,
        address _treasury,
        address _owner
    ) public initializer {
        __Ownable_init(_owner);
        token = CaDuCoinXToken(_token);
        usdc = IERC20(_usdc);
        tokenPrice = 8600;
        treasury = _treasury;
    }

    /**
     * @notice Atualiza o preço por token.
     * @param newPrice Novo preço por token (em USDC, considerando 6 decimais).
     */
    function updateTokenPrice(uint256 newPrice) external onlyOwner {
        tokenPrice = newPrice;
        emit TokenPriceUpdated(newPrice);
    }

    /**
     * @notice Compra tokens utilizando USDC.
     * O comprador deve aprovar a transferência do custo total para o contrato.
     * @param tokenAmount Quantidade de tokens a serem adquiridos (já considerando os decimais do token).
     */
    function purchaseTokens(uint256 tokenAmount) external {
        // Calcula o custo total em USDC.
        uint256 cost = tokenAmount * tokenPrice;
        
        // Verifica se o comprador permitiu essa quantidade.
        require(usdc.allowance(msg.sender, address(this)) >= cost, "Allowance insuficiente para USDC");

        // Transfere os USDC do comprador para o treasury.
        bool success = usdc.transferFrom(msg.sender, treasury, cost);
        require(success, "Transferencia de USDC falhou");

        // Mint os tokens para o comprador.
        // TODO: Ajustar controle do mint por OwnableUnauthorizedAccount
        token.mint(msg.sender, tokenAmount);
        emit TokensPurchased(msg.sender, tokenAmount, cost);
    }
}