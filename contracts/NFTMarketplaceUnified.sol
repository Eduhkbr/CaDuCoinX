// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IMarketplace.sol";

/**
 * @title NFTMarketplaceUnified
 * @dev Secure and upgradeable marketplace for NFT trading
 * @notice Unified marketplace for NFT assets with comprehensive security features
 * @author CaDuCoinX Team
 */
contract NFTMarketplaceUnified is
Initializable,
OwnableUpgradeable,
ReentrancyGuardUpgradeable,
PausableUpgradeable,
IMarketplace
{
    using SafeERC20 for IERC20;

    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /// @dev Maximum price to prevent overflow (1 million tokens)
    uint256 public constant MAX_PRICE = 1_000_000 * 1e18;

    /// @dev Minimum price to prevent zero-value listings
    uint256 public constant MIN_PRICE = 1e15; // 0.001 tokens

    /// @dev Maximum name length for gas optimization
    uint256 public constant MAX_NAME_LENGTH = 100;

    /// @dev Maximum category length for gas optimization
    uint256 public constant MAX_CATEGORY_LENGTH = 50;

    /// @dev Marketplace fee percentage (2.5%)
    uint256 public constant FEE_PERCENTAGE = 250; // 2.5% = 250/10000

    /// @dev Fee denominator for percentage calculations
    uint256 public constant FEE_DENOMINATOR = 10000;

    // =============================================================
    //                        STATE VARIABLES
    // =============================================================

    /// @dev Token used for payments
    IERC20 public paymentToken;

    /// @dev Address that receives marketplace fees
    address public feeCollector;

    /// @dev Counter for generating unique asset IDs
    uint256 public nextAssetId;

    /// @dev Total fees collected by the marketplace
    uint256 public totalFeesCollected;

    // =============================================================
    //                           STRUCTS
    // =============================================================

    /**
     * @dev Structure representing a listed asset
     * @param id Unique identifier for the asset
     * @param name Name/description of the asset
     * @param price Price in payment tokens
     * @param seller Address of the asset seller
     * @param category Category classification
     * @param isActive Whether the listing is active
     * @param createdAt Timestamp when the asset was listed
     */
    struct Asset {
        uint256 id;
        string name;
        uint256 price;
        address seller;
        string category;
        bool isActive;
        uint256 createdAt;
    }

    // =============================================================
    //                           MAPPINGS
    // =============================================================

    /// @dev Mapping from asset ID to asset details
    mapping(uint256 => Asset) public assets;

    /// @dev Mapping from seller to their listed asset IDs
    mapping(address => uint256[]) public sellerAssets;

    /// @dev Mapping to check if an asset ID exists
    mapping(uint256 => bool) public assetExists;

    // =============================================================
    //                            EVENTS
    // =============================================================

    /// @dev Emitted when an asset is listed
    event AssetListed(
        uint256 indexed assetId,
        address indexed seller,
        string name,
        uint256 price,
        string category,
        uint256 timestamp
    );

    /// @dev Emitted when an asset is purchased
    event AssetPurchased(
        uint256 indexed assetId,
        address indexed buyer,
        address indexed seller,
        uint256 price,
        uint256 fee,
        uint256 timestamp
    );

    /// @dev Emitted when an asset is delisted
    event AssetDelisted(uint256 indexed assetId, address indexed seller, uint256 timestamp);

    /// @dev Emitted when marketplace fee is updated
    event FeeCollectorUpdated(address indexed oldCollector, address indexed newCollector);

    /// @dev Emitted when fees are withdrawn
    event FeesWithdrawn(address indexed collector, uint256 amount);

    // =============================================================
    //                          MODIFIERS
    // =============================================================

    /**
     * @dev Ensures the asset exists and is active
     * @param assetId The ID of the asset to check
     */
    modifier assetIsActive(uint256 assetId) {
        require(assetExists[assetId], "Asset does not exist");
        require(assets[assetId].isActive, "Asset is not active");
        _;
    }

    /**
     * @dev Ensures the caller is the seller of the asset
     * @param assetId The ID of the asset
     */
    modifier onlySeller(uint256 assetId) {
        require(assets[assetId].seller == msg.sender, "Not the asset seller");
        _;
    }

    /**
     * @dev Validates string input length
     * @param str The string to validate
     * @param maxLength The maximum allowed length
     */
    modifier validString(string memory str, uint256 maxLength) {
        require(bytes(str).length > 0, "String cannot be empty");
        require(bytes(str).length <= maxLength, "String too long");
        _;
    }

    /**
     * @dev Validates price is within acceptable range
     * @param price The price to validate
     */
    modifier validPrice(uint256 price) {
        require(price >= MIN_PRICE && price <= MAX_PRICE, "Price out of range");
        _;
    }

    // =============================================================
    //                        CONSTRUCTOR
    // =============================================================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // =============================================================
    //                      INITIALIZATION
    // =============================================================

    /**
     * @notice Initializes the NFT marketplace
     * @dev This function replaces the constructor for upgradeable contracts
     * @param _paymentToken Address of the token used for payments
     * @param _owner Address of the contract owner
     * @param _feeCollector Address that will receive marketplace fees
     */
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
        nextAssetId = 1; // Start IDs from 1
    }

    // =============================================================
    //                    MARKETPLACE FUNCTIONS
    // =============================================================

    /**
     * @notice Lists an asset for sale in the marketplace
     * @dev Creates a new asset listing with validation
     * @param name Name/description of the asset
     * @param price Price of the asset in payment tokens
     * @param category Category of the asset
     */
    function listAsset(
        string memory name,
        uint256 price,
        string memory category
    )
    external
    override
    whenNotPaused
    validString(name, MAX_NAME_LENGTH)
    validString(category, MAX_CATEGORY_LENGTH)
    validPrice(price)
    {
        uint256 assetId = nextAssetId++;

        assets[assetId] = Asset({
            id: assetId,
            name: name,
            price: price,
            seller: msg.sender,
            category: category,
            isActive: true,
            createdAt: block.timestamp
        });

        assetExists[assetId] = true;
        sellerAssets[msg.sender].push(assetId);

        emit AssetListed(assetId, msg.sender, name, price, category, block.timestamp);
    }

    /**
     * @notice Purchases a listed asset
     * @dev Transfers payment from buyer to seller (minus fees) and marks asset as sold
     * @param assetId ID of the asset to purchase
     */
    function purchaseAsset(uint256 assetId)
    external
    override
    whenNotPaused
    nonReentrant
    assetIsActive(assetId)
    {
        Asset storage asset = assets[assetId];
        require(asset.seller != msg.sender, "Cannot purchase own asset");

        uint256 fee = (asset.price * FEE_PERCENTAGE) / FEE_DENOMINATOR;
        uint256 sellerAmount = asset.price - fee;

        // Mark asset as inactive before transfers to prevent reentrancy
        asset.isActive = false;
        totalFeesCollected += fee;

        // Transfer payment token from buyer
        paymentToken.safeTransferFrom(msg.sender, asset.seller, sellerAmount);
        if (fee > 0) {
            paymentToken.safeTransferFrom(msg.sender, feeCollector, fee);
        }

        emit AssetPurchased(assetId, msg.sender, asset.seller, asset.price, fee, block.timestamp);
    }

    /**
     * @notice Removes an asset from the marketplace
     * @dev Only the seller can delist their own assets
     * @param assetId ID of the asset to delist
     */
    function delistAsset(uint256 assetId)
    external
    override
    assetIsActive(assetId)
    onlySeller(assetId)
    {
        assets[assetId].isActive = false;
        emit AssetDelisted(assetId, msg.sender, block.timestamp);
    }

    /**
     * @notice Updates the price of a listed asset
     * @dev Only the seller can update their asset price
     * @param assetId ID of the asset to update
     * @param newPrice New price for the asset
     */
    function updateAssetPrice(uint256 assetId, uint256 newPrice)
    external
    assetIsActive(assetId)
    onlySeller(assetId)
    validPrice(newPrice)
    {
        assets[assetId].price = newPrice;
        emit AssetListed(
            assetId,
            msg.sender,
            assets[assetId].name,
            newPrice,
            assets[assetId].category,
            block.timestamp
        );
    }

    // =============================================================
    //                       ADMIN FUNCTIONS
    // =============================================================

    /**
     * @notice Updates the fee collector address
     * @dev Only the contract owner can update the fee collector
     * @param newFeeCollector New address to receive marketplace fees
     */
    function setFeeCollector(address newFeeCollector) external onlyOwner {
        require(newFeeCollector != address(0), "Fee collector cannot be zero address");

        address oldCollector = feeCollector;
        feeCollector = newFeeCollector;

        emit FeeCollectorUpdated(oldCollector, newFeeCollector);
    }

    /**
     * @notice Pauses the marketplace
     * @dev Only the contract owner can pause operations
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses the marketplace
     * @dev Only the contract owner can unpause operations
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Emergency function to delist any asset
     * @dev Only the contract owner can use this function
     * @param assetId ID of the asset to delist
     */
    function emergencyDelistAsset(uint256 assetId) external onlyOwner assetIsActive(assetId) {
        assets[assetId].isActive = false;
        emit AssetDelisted(assetId, assets[assetId].seller, block.timestamp);
    }

    // =============================================================
    //                       VIEW FUNCTIONS
    // =============================================================

    /**
     * @notice Gets detailed information about an asset
     * @dev Returns all asset details including activity status
     * @param assetId ID of the asset to query
     * @return id Asset ID
     * @return name Asset name
     * @return price Asset price
     * @return seller Seller address
     * @return category Asset category
     */
    function getAsset(uint256 assetId)
    external
    view
    override
    returns (
        uint256 id,
        string memory name,
        uint256 price,
        address seller,
        string memory category
    )
    {
        require(assetExists[assetId], "Asset does not exist");
        Asset memory asset = assets[assetId];
        return (asset.id, asset.name, asset.price, asset.seller, asset.category);
    }

    /**
     * @notice Gets complete asset information including status and timestamp
     * @param assetId ID of the asset to query
     * @return Complete asset struct
     */
    function getAssetDetails(uint256 assetId) external view returns (Asset memory) {
        require(assetExists[assetId], "Asset does not exist");
        return assets[assetId];
    }

    /**
     * @notice Gets all asset IDs listed by a specific seller
     * @param seller Address of the seller
     * @return Array of asset IDs
     */
    function getSellerAssets(address seller) external view returns (uint256[] memory) {
        return sellerAssets[seller];
    }

    /**
     * @notice Gets the number of assets listed by a seller
     * @param seller Address of the seller
     * @return Number of assets listed
     */
    function getSellerAssetCount(address seller) external view returns (uint256) {
        return sellerAssets[seller].length;
    }

    /**
     * @notice Checks if an asset is currently active
     * @param assetId ID of the asset to check
     * @return Whether the asset is active
     */
    function isAssetActive(uint256 assetId) external view returns (bool) {
        return assetExists[assetId] && assets[assetId].isActive;
    }

    /**
     * @notice Calculates the fee for a given price
     * @param price The price to calculate fee for
     * @return The fee amount
     */
    function calculateFee(uint256 price) external pure returns (uint256) {
        return (price * FEE_PERCENTAGE) / FEE_DENOMINATOR;
    }

    /**
     * @notice Gets the current marketplace statistics
     * @return totalAssets Total number of assets ever listed
     * @return totalFees Total fees collected
     * @return feePercentage Current fee percentage
     */
    function getMarketplaceStats() external view returns (
        uint256 totalAssets,
        uint256 totalFees,
        uint256 feePercentage
    ) {
        return (nextAssetId - 1, totalFeesCollected, FEE_PERCENTAGE);
    }
}