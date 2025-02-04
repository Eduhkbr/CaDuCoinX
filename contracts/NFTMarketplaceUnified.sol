// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol"; 
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol"; 
import "@openzeppelin/contracts/token/ERC721/IERC721.sol"; 
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title NFTMarketplaceUnified
 * @dev Marketplace unificado para negociação de NFTs usando o token de pagamento unificado.
 * Utiliza o padrão upgradeable.
 */
contract NFTMarketplaceUnified is Initializable, OwnableUpgradeable {
    // Token utilizado para pagamento (ex: CaDuCoinXToken).
    IERC20 public paymentToken;

    // Estrutura para armazenar informações da venda.
    struct Sale {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price; // Preço em unidades do token unificado.
    }

    // Mapeia um ID único de venda para os detalhes da transação.
    mapping(uint256 => Sale) public sales;
    uint256 public nextSaleId;

    // Eventos para auditoria.
    event NFTListed(uint256 saleId, address indexed seller, address nftContract, uint256 tokenId, uint256 price);
    event NFTPurchased(uint256 saleId, address indexed buyer, uint256 price);
    event NFTDelisted(uint256 saleId);

    /**
     * @notice Inicializa o marketplace especificando o token de pagamento.
     * @param _paymentToken Endereço do token unificado (ERC20).
     */
    function initialize(IERC20 _paymentToken, address _owner) public initializer {
        __Ownable_init(_owner);
        paymentToken = _paymentToken;
    }

    /**
     * @notice Lista um NFT para venda no marketplace.
     * @param nftContract Endereço do contrato ERC721 do NFT.
     * @param tokenId ID do token NFT.
     * @param price Preço do NFT (em unidades do token unificado).
     */
    function listNFT(address nftContract, uint256 tokenId, uint256 price) external {
        require(price > 0, "Price must be greater than zero");

        // Verifica se o chamador é o dono do NFT e se o contrato está autorizado para transferir o NFT.
        IERC721 nft = IERC721(nftContract);
        require(nft.ownerOf(tokenId) == msg.sender, "Caller is not the NFT owner");
        require(
            nft.getApproved(tokenId) == address(this) || nft.isApprovedForAll(msg.sender, address(this)),
            "Marketplace not approved"
        );

        sales[nextSaleId] = Sale({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            price: price
        });

        emit NFTListed(nextSaleId, msg.sender, nftContract, tokenId, price);
        nextSaleId++;
    }

    /**
     * @notice Permite a compra de um NFT listado.
     * @param saleId ID da venda.
     */
    function purchaseNFT(uint256 saleId) external {
        Sale memory sale = sales[saleId];
        require(sale.price > 0, "Sale does not exist");

        // Transfere o token de pagamento do comprador para o vendedor.
        require(
            paymentToken.transferFrom(msg.sender, sale.seller, sale.price),
            "Payment transfer failed"
        );

        // Transfere o NFT do vendedor para o comprador.
        IERC721(sale.nftContract).transferFrom(sale.seller, msg.sender, sale.tokenId);

        // Remove a listagem para evitar reentrância ou compras duplicadas.
        delete sales[saleId];

        emit NFTPurchased(saleId, msg.sender, sale.price);
    }

    /**
     * @notice Permite ao vendedor delistar seu NFT.
     * @param saleId ID da venda.
     */
    function delistNFT(uint256 saleId) external {
        Sale memory sale = sales[saleId];
        require(sale.seller == msg.sender, "Not the seller");
        delete sales[saleId];
        emit NFTDelisted(saleId);
    }
}