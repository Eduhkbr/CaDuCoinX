// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/**
 * @title CaDuCoinXToken
 * @dev Upgradeable ERC20 token with trading functionality and role-based access control.
 * Implements pause mechanism, reentrancy protection, and secure token trading.
 * @author Eduhkbr
 * @notice This token is designed for microtransactions and unified gamification ecosystem
 */
contract CaDuCoinXToken is
    Initializable,
    AccessControlUpgradeable,
    ERC20PausableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    // =============================================================
    //                           CONSTANTS
    // =============================================================

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant PRICE_UPDATER_ROLE = keccak256("PRICE_UPDATER_ROLE");

    uint256 public constant MAX_PRICE = 100 ether;
    uint256 public constant MIN_PRICE = 1e12;
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 1e18;
    uint256 public constant SELL_PRICE_PERCENTAGE = 98;

    // =============================================================
    //                        STATE VARIABLES
    // =============================================================

    uint256 public salePrice;
    uint256 public sellPrice;
    bool public saleActive;

    /// @dev Reserved storage space for future upgrades
    uint256[47] private __gap;

    // =============================================================
    //                            EVENTS
    // =============================================================

    event SalePriceUpdated(uint256 indexed newSalePrice, uint256 indexed newSellPrice);
    event SaleStatusUpdated(bool indexed newStatus);
    event TokensPurchased(address indexed buyer, uint256 tokenAmount, uint256 ethAmount);
    event TokensSold(address indexed seller, uint256 tokenAmount, uint256 ethAmount);
    event EthWithdrawn(address indexed admin, uint256 amount);
    event EthDeposited(address indexed depositor, uint256 amount);
    event TokensBurned(address indexed burner, uint256 amount);

    // =============================================================
    //                          MODIFIERS
    // =============================================================

    modifier withinSupplyCap(uint256 amount) {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds maximum supply");
        _;
    }

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

    function initialize(
        address defaultAdmin,
        string memory name,
        string memory symbol
    ) public initializer {
        require(defaultAdmin != address(0), "Admin cannot be zero address");
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(symbol).length > 0, "Symbol cannot be empty");

        __ERC20_init(name, symbol);
        __ERC20Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, defaultAdmin);
        _grantRole(UPGRADER_ROLE, defaultAdmin);
        _grantRole(PRICE_UPDATER_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, defaultAdmin);

        salePrice = 3300000000000; // 0.0000033 ETH
        sellPrice = (salePrice * SELL_PRICE_PERCENTAGE) / 100;
        saleActive = true;

        emit SalePriceUpdated(salePrice, sellPrice);
        emit SaleStatusUpdated(true);
    }

    // =============================================================
    //                      TOKEN FUNCTIONS
    // =============================================================

    function mint(address to, uint256 amount)
        public
        onlyRole(MINTER_ROLE)
        withinSupplyCap(amount)
    {
        require(to != address(0), "Cannot mint to zero address");
        require(amount > 0, "Amount must be greater than zero");
        _mint(to, amount);
    }

    function burn(uint256 amount) public {
        require(amount > 0, "Amount must be greater than zero");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance to burn");
        _burn(msg.sender, amount);
        emit TokensBurned(msg.sender, amount);
    }

    function burnFrom(address from, uint256 amount) public {
        require(amount > 0, "Amount must be greater than zero");
        require(from != address(0), "Cannot burn from zero address");

        uint256 currentAllowance = allowance(from, msg.sender);
        require(currentAllowance >= amount, "Burn amount exceeds allowance");

        _approve(from, msg.sender, currentAllowance - amount);
        _burn(from, amount);
        emit TokensBurned(from, amount);
    }

    // =============================================================
    //                    PRICE MANAGEMENT
    // =============================================================

    function updateSalePrice(uint256 newSalePrice)
        public
        onlyRole(PRICE_UPDATER_ROLE)
        validPrice(newSalePrice)
    {
        salePrice = newSalePrice;
        sellPrice = (newSalePrice * SELL_PRICE_PERCENTAGE) / 100;
        emit SalePriceUpdated(salePrice, sellPrice);
    }

    function setSaleActive(bool active) public onlyRole(DEFAULT_ADMIN_ROLE) {
        saleActive = active;
        emit SaleStatusUpdated(active);
    }

    // =============================================================
    //                   TOKEN TRADING FUNCTIONS
    // =============================================================

    /**
     * @notice Allows users to purchase tokens with ETH
     * @dev Mints tokens based on the amount of ETH sent and current sale price.
     * Users MUST call this function explicitly (no implicit purchase via receive/fallback).
     */
    function purchaseTokens()
        public
        payable
        whenNotPaused
        nonReentrant
    {
        require(saleActive, "Token sale is not active");
        require(msg.value > 0, "Must send ETH to purchase tokens");

        uint256 tokensToMint = (msg.value * 10**decimals()) / salePrice;
        require(tokensToMint > 0, "ETH amount too small");
        require(totalSupply() + tokensToMint <= MAX_SUPPLY, "Purchase exceeds max supply");

        _mint(msg.sender, tokensToMint);
        emit TokensPurchased(msg.sender, tokensToMint, msg.value);
    }

    /**
     * @notice Allows users to sell tokens back for ETH
     * @dev Burns tokens and sends ETH based on current sell price.
     * Follows checks-effects-interactions pattern.
     */
    function sellTokens(uint256 tokenAmount)
        public
        whenNotPaused
        nonReentrant
    {
        require(tokenAmount > 0, "Amount must be greater than zero");
        require(balanceOf(msg.sender) >= tokenAmount, "Insufficient token balance");

        uint256 ethToSend = (tokenAmount * sellPrice) / 10**decimals();
        require(ethToSend > 0, "ETH amount too small");
        require(address(this).balance >= ethToSend, "Contract has insufficient ETH balance");

        // Burn BEFORE sending ETH (checks-effects-interactions)
        _burn(msg.sender, tokenAmount);

        (bool success, ) = payable(msg.sender).call{value: ethToSend}("");
        require(success, "ETH transfer failed");

        emit TokensSold(msg.sender, tokenAmount, ethToSend);
    }

    /**
     * @notice Deposits ETH to fund token sell-backs
     * @dev Only admin can deposit ETH. This is the proper way to fund the contract.
     */
    function depositEth() public payable onlyRole(DEFAULT_ADMIN_ROLE) {
        require(msg.value > 0, "Must send ETH");
        emit EthDeposited(msg.sender, msg.value);
    }

    /**
     * @notice Withdraws excess ETH above the required reserve
     */
    function withdraw() public onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        uint256 required = requiredBalance();
        uint256 current = contractBalance();
        require(current > required, "No excess balance to withdraw");

        uint256 amountToWithdraw = current - required;

        (bool success, ) = payable(msg.sender).call{value: amountToWithdraw}("");
        require(success, "Withdrawal failed");

        emit EthWithdrawn(msg.sender, amountToWithdraw);
    }

    /**
     * @notice Emergency withdrawal of all ETH. Requires contract to be paused.
     */
    function emergencyWithdraw() public onlyRole(DEFAULT_ADMIN_ROLE) whenPaused nonReentrant {
        uint256 bal = contractBalance();
        require(bal > 0, "No balance to withdraw");

        (bool success, ) = payable(msg.sender).call{value: bal}("");
        require(success, "Emergency withdrawal failed");

        emit EthWithdrawn(msg.sender, bal);
    }

    // =============================================================
    //                    PAUSABLE FUNCTIONS
    // =============================================================

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // =============================================================
    //                     VIEW FUNCTIONS
    // =============================================================

    function calculateTokensForEth(uint256 ethAmount) public view returns (uint256) {
        if (ethAmount == 0 || salePrice == 0) return 0;
        return (ethAmount * 10**decimals()) / salePrice;
    }

    function calculateEthForTokens(uint256 tokenAmount) public view returns (uint256) {
        if (tokenAmount == 0 || sellPrice == 0) return 0;
        return (tokenAmount * sellPrice) / 10**decimals();
    }

    function contractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function requiredBalance() public view returns (uint256) {
        return (totalSupply() * sellPrice) / 10**decimals();
    }

    function excessBalance() public view returns (uint256) {
        uint256 required = requiredBalance();
        uint256 current = contractBalance();
        return current > required ? current - required : 0;
    }

    // =============================================================
    //                    UPGRADE AUTHORIZATION
    // =============================================================

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
        view
    {
        require(newImplementation != address(0), "New implementation cannot be zero address");
    }

    // =============================================================
    //                       OVERRIDES
    // =============================================================

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20PausableUpgradeable) {
        super._update(from, to, value);
    }
}