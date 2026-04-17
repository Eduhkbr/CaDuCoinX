// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title NFTMarketplaceUnified
 * @dev Secure upgradeable NFT marketplace with escrow pattern.
 * NFTs are held in escrow by the marketplace until purchased or delisted.
 * @author CaDuCoinX Team
 */
contract NFTMarketplaceUnified is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeERC20 for IERC20;

    // =============================================================
    //                           CONSTANTS
    // =============================================================

    uint256 public constant MAX_PRICE = 1_000_000 * 1e18;
    uint256 public constant MIN_PRICE = 1e15;
    uint256 public constant FEE_PERCENTAGE = 250; // 2.5%
    uint256 public constant FEE_DENOMINATOR = 10000;

    // =============================================================
    //                        STATE VARIABLES
    // =============================================================

    IERC20 public paymentToken;
    address public feeCollector;
    uint256 public nextAssetId;
    uint256 public totalFeesCollected;

    // =============================================================
    //                           STRUCTS
    // =============================================================

    struct Asset {
        uint256 id;
        address nftAddress;
        uint256 tokenId;
        uint256 price;
        address seller;
        bool isActive;
        uint256 createdAt;
    }

    // =============================================================
    //                           MAPPINGS
    // =============================================================

    mapping(uint256 => Asset) public assets;
    mapping(address => uint256[]) public sellerAssets;
    mapping(uint256 => bool) public assetExists;

    /// @dev Prevents the same NFT from being listed twice
    mapping(address => mapping(uint256 => uint256)) public nftToAssetId;

    /// @dev Reserved storage space for future upgrades
    uint256[42] private __gap;

    // =============================================================
    //                            EVENTS
    // =============================================================

    event AssetListed(
        uint256 indexed assetId,
        address indexed seller,
        address indexed nftAddress,
        uint256 tokenId,
        uint256 price,
        uint256 timestamp
    );

    event AssetPurchased(
        uint256 indexed assetId,
        address indexed buyer,
        address indexed seller,
        uint256 price,
        uint256 fee,
        uint256 timestamp
    );

    event AssetDelisted(uint256 indexed assetId, address indexed seller, uint256 timestamp);
    event AssetPriceUpdated(uint256 indexed assetId, uint256 oldPrice, uint256 newPrice);
    event FeeCollectorUpdated(address indexed oldCollector, address indexed newCollector);

    // =============================================================
    //                          MODIFIERS
    // =============================================================

    modifier assetIsActive(uint256 assetId) {
        require(assetExists[assetId], "Asset does not exist");
        require(assets[assetId].isActive, "Asset is not active");
        _;
    }

    modifier onlySeller(uint256 assetId) {
        require(assets[assetId].seller == msg.sender, "Not the asset seller");
        _;
    }

    modifier validPrice(uint256 price) {
        require(price >= MIN_PRICE && price <= MAX_PRICE, "Price out of range");
        _;
    }

    // =============================================================
    //                      INITIALIZATION
    // =============================================================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        IERC20 _paymentToken,
        address _owner,
        address _feeCollector
    ) public initializer {
        require(address(_paymentToken) != address(0), "Payment token cannot be zero address");
        require(_owner != address(0), "Owner cannot be zero address");
        require(_feeCollector != address(0), "Fee collector cannot be zero address");

        __Ownable_init(_owner);
        __ReentrancyGuard_init();
        __Pausable_init();

        paymentToken = _paymentToken;
        feeCollector = _feeCollector;
        nextAssetId = 1;
    }

    // =============================================================
    //                    MARKETPLACE FUNCTIONS
    // =============================================================

    /**
     * @notice Lists an NFT for sale with escrow.
     * @dev The seller must approve this contract to transfer the NFT BEFORE calling this.
     * The NFT is transferred to the marketplace (escrow) upon listing.
     * @param _nftAddress The address of the ERC721 contract
     * @param _tokenId The token ID of the NFT
     * @param _price The listing price in payment tokens
     */
    function listAsset(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _price
    )
        external
        whenNotPaused
        validPrice(_price)
    {
        require(_nftAddress != address(0), "NFT address cannot be zero");

        IERC721 nft = IERC721(_nftAddress);
        require(nft.ownerOf(_tokenId) == msg.sender, "Not the owner of the NFT");
        require(
            nft.getApproved(_tokenId) == address(this) || nft.isApprovedForAll(msg.sender, address(this)),
            "Marketplace not approved to transfer NFT"
        );

        // Prevent duplicate listings of the same NFT
        uint256 existingAssetId = nftToAssetId[_nftAddress][_tokenId];
        require(
            existingAssetId == 0 || !assets[existingAssetId].isActive,
            "NFT already listed"
        );

        // Escrow: transfer NFT to marketplace
        nft.transferFrom(msg.sender, address(this), _tokenId);

        uint256 assetId = nextAssetId++;

        assets[assetId] = Asset({
            id: assetId,
            nftAddress: _nftAddress,
            tokenId: _tokenId,
            price: _price,
            seller: msg.sender,
            isActive: true,
            createdAt: block.timestamp
        });

        assetExists[assetId] = true;
        sellerAssets[msg.sender].push(assetId);
        nftToAssetId[_nftAddress][_tokenId] = assetId;

        emit AssetListed(assetId, msg.sender, _nftAddress, _tokenId, _price, block.timestamp);
    }

    /**
     * @notice Purchases a listed NFT.
     * @dev Payment is split between seller and fee collector.
     * NFT is transferred from escrow to the buyer.
     * @param assetId ID of the asset to purchase
     */
    function purchaseAsset(uint256 assetId)
        external
        whenNotPaused
        nonReentrant
        assetIsActive(assetId)
    {
        Asset storage asset = assets[assetId];
        require(asset.seller != msg.sender, "Cannot purchase own asset");

        uint256 fee = (asset.price * FEE_PERCENTAGE) / FEE_DENOMINATOR;
        uint256 sellerAmount = asset.price - fee;

        // Effects before interactions
        asset.isActive = false;
        totalFeesCollected += fee;

        // Transfer payment tokens
        paymentToken.safeTransferFrom(msg.sender, asset.seller, sellerAmount);
        if (fee > 0) {
            paymentToken.safeTransferFrom(msg.sender, feeCollector, fee);
        }

        // Transfer NFT from escrow to buyer
        IERC721(asset.nftAddress).transferFrom(address(this), msg.sender, asset.tokenId);

        emit AssetPurchased(assetId, msg.sender, asset.seller, asset.price, fee, block.timestamp);
    }

    /**
     * @notice Removes an NFT listing and returns the NFT to the seller.
     * @param assetId ID of the asset to delist
     */
    function delistAsset(uint256 assetId)
        external
        assetIsActive(assetId)
        onlySeller(assetId)
    {
        Asset storage asset = assets[assetId];
        asset.isActive = false;

        // Return NFT from escrow to seller
        IERC721(asset.nftAddress).transferFrom(address(this), msg.sender, asset.tokenId);

        emit AssetDelisted(assetId, msg.sender, block.timestamp);
    }

    /**
     * @notice Updates the price of a listed NFT
     * @param assetId ID of the asset to update
     * @param newPrice New price for the asset
     */
    function updateAssetPrice(uint256 assetId, uint256 newPrice)
        external
        assetIsActive(assetId)
        onlySeller(assetId)
        validPrice(newPrice)
    {
        uint256 oldPrice = assets[assetId].price;
        assets[assetId].price = newPrice;
        emit AssetPriceUpdated(assetId, oldPrice, newPrice);
    }

    // =============================================================
    //                       ADMIN FUNCTIONS
    // =============================================================

    function setFeeCollector(address newFeeCollector) external onlyOwner {
        require(newFeeCollector != address(0), "Fee collector cannot be zero address");
        address oldCollector = feeCollector;
        feeCollector = newFeeCollector;
        emit FeeCollectorUpdated(oldCollector, newFeeCollector);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Emergency function to delist any asset and return NFT to seller
     * @param assetId ID of the asset to emergency delist
     */
    function emergencyDelistAsset(uint256 assetId) external onlyOwner {
        require(assetExists[assetId], "Asset does not exist");
        require(assets[assetId].isActive, "Asset not active");

        Asset storage asset = assets[assetId];
        asset.isActive = false;

        // Return NFT from escrow to seller
        IERC721(asset.nftAddress).transferFrom(address(this), asset.seller, asset.tokenId);

        emit AssetDelisted(assetId, asset.seller, block.timestamp);
    }

    // =============================================================
    //                       VIEW FUNCTIONS
    // =============================================================

    function getAssetDetails(uint256 assetId) external view returns (Asset memory) {
        require(assetExists[assetId], "Asset does not exist");
        return assets[assetId];
    }

    function getSellerAssets(address seller) external view returns (uint256[] memory) {
        return sellerAssets[seller];
    }

    /**
     * @notice Calculates cost breakdown for a purchase
     * @param assetId ID of the asset
     * @return buyerPays Total the buyer needs to approve/pay (= listed price)
     * @return sellerReceives Amount the seller receives after fee deduction
     * @return fee Fee amount deducted from the seller's proceeds
     */
    function calculateCost(uint256 assetId)
        external
        view
        returns (uint256 buyerPays, uint256 sellerReceives, uint256 fee)
    {
        require(assetExists[assetId], "Asset does not exist");
        buyerPays = assets[assetId].price;
        fee = (buyerPays * FEE_PERCENTAGE) / FEE_DENOMINATOR;
        sellerReceives = buyerPays - fee;
    }

    function getMarketplaceStats()
        external
        view
        returns (uint256 totalAssets, uint256 totalFees, uint256 feePercentage)
    {
        return (nextAssetId - 1, totalFeesCollected, FEE_PERCENTAGE);
    }

    // =============================================================
    //                    ERC721 RECEIVER
    // =============================================================

    /**
     * @notice Handles the receipt of an NFT (required for safeTransferFrom compatibility)
     */
    function onERC721Received(address, address, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return this.onERC721Received.selector;
    }
}