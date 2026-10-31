// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract CaDuCoinXNFTMarketplace is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    IERC721Receiver
{
    using SafeERC20 for IERC20;

    uint256 public constant FEE_BPS = 90; // 0.9%
    uint256 public constant BPS_DENOMINATOR = 10_000;

    struct Listing {
        address seller;
        uint256 price;
    }

    IERC20 public paymentToken;
    address public feeCollector;
    mapping(address => mapping(uint256 => Listing)) public listings;

    address private _pendingNFT;
    address private _pendingSeller;
    uint256 private _pendingTokenId;

    event NFTListed(address indexed seller, address indexed nft, uint256 indexed tokenId, uint256 price);
    event NFTPurchased(
        address indexed buyer,
        address indexed seller,
        address indexed nft,
        uint256 tokenId,
        uint256 price,
        uint256 fee
    );
    event ListingCancelled(address indexed seller, address indexed nft, uint256 indexed tokenId);
    event ListingPriceUpdated(address indexed seller, address indexed nft, uint256 indexed tokenId, uint256 price);
    event FeeCollectorUpdated(address indexed oldCollector, address indexed newCollector);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address paymentToken_, address owner_, address feeCollector_) external initializer {
        require(paymentToken_ != address(0) && paymentToken_.code.length > 0, "Invalid payment token");
        require(owner_ != address(0), "Invalid owner");
        require(feeCollector_ != address(0), "Invalid fee collector");

        __Ownable_init(owner_);
        __UUPSUpgradeable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        paymentToken = IERC20(paymentToken_);
        feeCollector = feeCollector_;
    }

    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
        require(newImplementation.code.length > 0, "Invalid implementation");
    }

    function listNFT(address nft, uint256 tokenId, uint256 price) external nonReentrant whenNotPaused {
        require(nft.code.length > 0, "Invalid NFT contract");
        require(price > 0, "Price must be positive");
        require(listings[nft][tokenId].seller == address(0), "Already listed");
        require(IERC721(nft).ownerOf(tokenId) == msg.sender, "Not NFT owner");

        _pendingNFT = nft;
        _pendingSeller = msg.sender;
        _pendingTokenId = tokenId;
        IERC721(nft).safeTransferFrom(msg.sender, address(this), tokenId);
        delete _pendingNFT;
        delete _pendingSeller;
        delete _pendingTokenId;

        require(IERC721(nft).ownerOf(tokenId) == address(this), "Escrow failed");
        listings[nft][tokenId] = Listing({seller: msg.sender, price: price});
        emit NFTListed(msg.sender, nft, tokenId, price);
    }

    function buyNFT(address nft, uint256 tokenId) external nonReentrant whenNotPaused {
        Listing memory listing = listings[nft][tokenId];
        require(listing.seller != address(0) && listing.price > 0, "NFT not listed");
        require(msg.sender != listing.seller, "Cannot buy own NFT");
        require(IERC721(nft).ownerOf(tokenId) == address(this), "NFT not in escrow");

        delete listings[nft][tokenId];
        uint256 fee = Math.mulDiv(listing.price, FEE_BPS, BPS_DENOMINATOR);
        paymentToken.safeTransferFrom(msg.sender, listing.seller, listing.price - fee);
        if (fee > 0) paymentToken.safeTransferFrom(msg.sender, feeCollector, fee);

        IERC721(nft).safeTransferFrom(address(this), msg.sender, tokenId);
        require(IERC721(nft).ownerOf(tokenId) == msg.sender, "NFT transfer failed");
        emit NFTPurchased(msg.sender, listing.seller, nft, tokenId, listing.price, fee);
    }

    function cancelListing(address nft, uint256 tokenId) external nonReentrant {
        Listing memory listing = listings[nft][tokenId];
        require(listing.seller == msg.sender, "Not NFT seller");

        delete listings[nft][tokenId];
        IERC721(nft).safeTransferFrom(address(this), msg.sender, tokenId);
        emit ListingCancelled(msg.sender, nft, tokenId);
    }

    function updateListingPrice(address nft, uint256 tokenId, uint256 newPrice) external whenNotPaused {
        require(newPrice > 0, "Price must be positive");
        Listing storage listing = listings[nft][tokenId];
        require(listing.seller == msg.sender, "Not NFT seller");
        listing.price = newPrice;
        emit ListingPriceUpdated(msg.sender, nft, tokenId, newPrice);
    }

    function setFeeCollector(address newFeeCollector) external onlyOwner {
        require(newFeeCollector != address(0), "Invalid fee collector");
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

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata)
        external
        view
        override
        returns (bytes4)
    {
        require(
            msg.sender == _pendingNFT && operator == address(this) &&
                from == _pendingSeller && tokenId == _pendingTokenId,
            "Unsolicited NFT"
        );
        return IERC721Receiver.onERC721Received.selector;
    }
}
