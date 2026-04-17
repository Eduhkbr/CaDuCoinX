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
 * @title ItemsMarketplaceUnified
 * @dev Secure and upgradeable marketplace for item trading
 * @notice Unified marketplace for game items with comprehensive security features
 * @author CaDuCoinX Team
 */
contract ItemsMarketplaceUnified is
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

    /// @dev Marketplace fee percentage (1.5% for items, lower than NFTs)
    uint256 public constant FEE_PERCENTAGE = 150; // 1.5% = 150/10000

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
     * @dev Structure representing a listed item
     * @param id Unique identifier for the item
     * @param name Name/description of the item
     * @param price Price in payment tokens
     * @param seller Address of the item seller
     * @param category Category classification
     * @param quantity Available quantity for this item
     * @param isActive Whether the listing is active
     * @param createdAt Timestamp when the item was listed
     */
    struct Asset {
        uint256 id;
        string name;
        uint256 price;
        address seller;
        string category;
        uint256 quantity;
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

    /// @dev Tracks if an asset was deliberately delisted (vs deactivated due to zero quantity)
    mapping(uint256 => bool) public deliberatelyDelisted;

    /// @dev Reserved storage space for future upgrades
    uint256[42] private __gap;

    // =============================================================
    //                            EVENTS
    // =============================================================

    /// @dev Emitted when an item is listed
    event AssetListed(
        uint256 indexed assetId,
        address indexed seller,
        string name,
        uint256 price,
        string category,
        uint256 quantity,
        uint256 timestamp
    );

    /// @dev Emitted when an item is purchased
    event AssetPurchased(
        uint256 indexed assetId,
        address indexed buyer,
        address indexed seller,
        uint256 price,
        uint256 quantity,
        uint256 fee,
        uint256 timestamp
    );

    /// @dev Emitted when an item is delisted
    event AssetDelisted(uint256 indexed assetId, address indexed seller, uint256 timestamp);

    /// @dev Emitted when item quantity is updated
    event QuantityUpdated(uint256 indexed assetId, uint256 newQuantity);

    /// @dev Emitted when marketplace fee collector is updated
    event FeeCollectorUpdated(address indexed oldCollector, address indexed newCollector);

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
        require(assets[assetId].quantity > 0, "Asset out of stock");
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

    /**
     * @dev Validates quantity is greater than zero
     * @param quantity The quantity to validate
     */
    modifier validQuantity(uint256 quantity) {
        require(quantity > 0, "Quantity must be greater than zero");
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
     * @notice Initializes the Items marketplace
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
     * @notice Lists an item for sale in the marketplace
     * @dev Creates a new item listing with validation and quantity support
     * @param name Name/description of the item
     * @param price Price of the item in payment tokens
     * @param category Category of the item
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
        listAssetWithQuantity(name, price, category, 1);
    }

    /**
     * @notice Lists an item with specific quantity for sale
     * @dev Creates a new item listing with custom quantity
     * @param name Name/description of the item
     * @param price Price per unit of the item
     * @param category Category of the item
     * @param quantity Number of items available
     */
    function listAssetWithQuantity(
        string memory name,
        uint256 price,
        string memory category,
        uint256 quantity
    )
    public
    whenNotPaused
    validString(name, MAX_NAME_LENGTH)
    validString(category, MAX_CATEGORY_LENGTH)
    validPrice(price)
    validQuantity(quantity)
    {
        uint256 assetId = nextAssetId++;

        assets[assetId] = Asset({
            id: assetId,
            name: name,
            price: price,
            seller: msg.sender,
            category: category,
            quantity: quantity,
            isActive: true,
            createdAt: block.timestamp
        });

        assetExists[assetId] = true;
        sellerAssets[msg.sender].push(assetId);

        emit AssetListed(assetId, msg.sender, name, price, category, quantity, block.timestamp);
    }

    /**
     * @notice Purchases one or more units of a listed item
     * @dev Transfers payment and updates quantity
     * @param assetId ID of the asset to purchase
     */
    function purchaseAsset(uint256 assetId)
    external
    override
    whenNotPaused
    assetIsActive(assetId)
    {
        purchaseAssetQuantity(assetId, 1);
    }

    /**
     * @notice Purchases a specific quantity of a listed item
     * @dev Transfers payment for multiple units and updates quantity
     * @param assetId ID of the asset to purchase
     * @param quantity Number of units to purchase
     */
    function purchaseAssetQuantity(uint256 assetId, uint256 quantity)
    public
    whenNotPaused
    nonReentrant
    assetIsActive(assetId)
    validQuantity(quantity)
    {
        Asset storage asset = assets[assetId];
        require(asset.seller != msg.sender, "Cannot purchase own asset");
        require(asset.quantity >= quantity, "Insufficient quantity available");

        uint256 totalPrice = asset.price * quantity;
        uint256 fee = (totalPrice * FEE_PERCENTAGE) / FEE_DENOMINATOR;
        uint256 sellerAmount = totalPrice - fee;

        // Update quantity before transfers to prevent reentrancy
        asset.quantity -= quantity;
        if (asset.quantity == 0) {
            asset.isActive = false;
        }
        totalFeesCollected += fee;

        // Transfer payment tokens
        paymentToken.safeTransferFrom(msg.sender, asset.seller, sellerAmount);
        if (fee > 0) {
            paymentToken.safeTransferFrom(msg.sender, feeCollector, fee);
        }

        emit AssetPurchased(assetId, msg.sender, asset.seller, asset.price, quantity, fee, block.timestamp);
    }

    /**
     * @notice Removes an item from the marketplace
     * @dev Only the seller can delist their own items
     * @param assetId ID of the asset to delist
     */
    function delistAsset(uint256 assetId)
    external
    override
    assetIsActive(assetId)
    onlySeller(assetId)
    {
        assets[assetId].isActive = false;
        deliberatelyDelisted[assetId] = true;
        emit AssetDelisted(assetId, msg.sender, block.timestamp);
    }

    /**
     * @notice Updates the price of a listed item
     * @dev Only the seller can update their item price
     * @param assetId ID of the asset to update
     * @param newPrice New price per unit for the asset
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
            assets[assetId].quantity,
            block.timestamp
        );
    }

    /**
     * @notice Updates the quantity of a listed item
     * @dev Only the seller can update their item quantity
     * @param assetId ID of the asset to update
     * @param newQuantity New quantity for the asset
     */
    function updateAssetQuantity(uint256 assetId, uint256 newQuantity)
    external
    onlySeller(assetId)
    validQuantity(newQuantity)
    {
        require(assetExists[assetId], "Asset does not exist");
        require(!deliberatelyDelisted[assetId], "Asset was deliberately delisted");

        assets[assetId].quantity = newQuantity;
        if (newQuantity > 0) {
            assets[assetId].isActive = true;
        }

        emit QuantityUpdated(assetId, newQuantity);
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
     * @notice Emergency function to delist any item
     * @dev Only the contract owner can use this function
     * @param assetId ID of the asset to delist
     */
    function emergencyDelistAsset(uint256 assetId) external onlyOwner {
        require(assetExists[assetId], "Asset does not exist");
        assets[assetId].isActive = false;
        deliberatelyDelisted[assetId] = true;
        emit AssetDelisted(assetId, assets[assetId].seller, block.timestamp);
    }

    // =============================================================
    //                       VIEW FUNCTIONS
    // =============================================================

    /**
     * @notice Gets detailed information about an item
     * @dev Returns basic asset details for interface compatibility
     * @param assetId ID of the asset to query
     * @return id Asset ID
     * @return name Asset name
     * @return price Asset price per unit
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
     * @notice Gets complete item information including quantity and status
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
     * @notice Gets the available quantity for an item
     * @param assetId ID of the asset to check
     * @return Available quantity
     */
    function getAssetQuantity(uint256 assetId) external view returns (uint256) {
        require(assetExists[assetId], "Asset does not exist");
        return assets[assetId].quantity;
    }

    /**
     * @notice Checks if an item is currently available for purchase
     * @param assetId ID of the asset to check
     * @return Whether the asset is available
     */
    function isAssetActive(uint256 assetId) external view returns (bool) {
        return assetExists[assetId] && assets[assetId].isActive && assets[assetId].quantity > 0;
    }

    /**
     * @notice Calculates the cost breakdown for purchasing multiple units
     * @param assetId ID of the asset
     * @param quantity Number of units
     * @return buyerPays Total the buyer needs to approve/pay (= listed price * quantity)
     * @return sellerReceives Amount the seller receives after fee deduction
     * @return fee Fee amount deducted from the seller's proceeds
     */
    function calculateTotalCost(uint256 assetId, uint256 quantity)
    external
    view
    returns (uint256 buyerPays, uint256 sellerReceives, uint256 fee)
    {
        require(assetExists[assetId], "Asset does not exist");

        buyerPays = assets[assetId].price * quantity;
        fee = (buyerPays * FEE_PERCENTAGE) / FEE_DENOMINATOR;
        sellerReceives = buyerPays - fee;
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