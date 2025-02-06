// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol"; 
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol"; 
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IMarketplace.sol";

/**
 * @title ItemsMarketplaceUnified
 * @dev Marketplace unificado para negociação de itens.
 * Implementa a interface IMarketplace.
 */
contract ItemsMarketplaceUnified is Initializable, OwnableUpgradeable, IMarketplace {
    // Token utilizado para pagamento (ex: CaDuCoinXToken)
    IERC20 public paymentToken;

    // Estrutura para representar um ativo (item) listado no marketplace.
    struct Asset {
        uint256 id;
        string name;
        uint256 price;
        address seller;
        string category;
    }

    mapping(uint256 => Asset) public assets;
    uint256 public nextAssetId;

    // Eventos para auditoria
    event AssetListed(uint256 indexed assetId, address indexed seller, string name, uint256 price, string category);
    event AssetPurchased(uint256 indexed assetId, address indexed buyer, uint256 price);
    event AssetDelisted(uint256 indexed assetId);

    /**
     * @notice Inicializa o marketplace.
     * @param _paymentToken Endereço do token utilizado para pagamento.
     * @param _owner Endereço do proprietário/admin do contrato.
     */
    function initialize(IERC20 _paymentToken, address _owner) public initializer {
        __Ownable_init(_owner);
        paymentToken = _paymentToken;
    }

    /**
     * @notice Lista um ativo para venda no marketplace.
     * @param name Nome/descritivo do ativo.
     * @param price Preço do ativo em tokens.
     * @param category Categoria do ativo (ex: "item").
     */
    function listAsset(string memory name, uint256 price, string memory category) external override {
        require(price > 0, "Price must be greater than zero");
        assets[nextAssetId] = Asset({
            id: nextAssetId,
            name: name,
            price: price,
            seller: msg.sender,
            category: category
        });
        emit AssetListed(nextAssetId, msg.sender, name, price, category);
        nextAssetId++;
    }

    /**
     * @notice Permite a compra de um ativo listado.
     * Transfere os tokens de pagamento do comprador para o vendedor e remove a listagem.
     * @param assetId ID do ativo a ser comprado.
     */
    function purchaseAsset(uint256 assetId) external override {
        Asset memory asset = assets[assetId];
        require(asset.price > 0, "Asset does not exist");
        require(
            paymentToken.transferFrom(msg.sender, asset.seller, asset.price),
            "Payment transfer failed"
        );
        delete assets[assetId];
        emit AssetPurchased(assetId, msg.sender, asset.price);
    }

    /**
     * @notice Permite ao vendedor delistar seu ativo.
     * @param assetId ID do ativo que será removido da listagem.
     */
    function delistAsset(uint256 assetId) external override {
        Asset memory asset = assets[assetId];
        require(asset.seller == msg.sender, "Caller is not the seller");
        delete assets[assetId];
        emit AssetDelisted(assetId);
    }
}