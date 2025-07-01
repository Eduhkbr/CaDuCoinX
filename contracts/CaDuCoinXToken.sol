// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

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
    using ECDSA for bytes32;

    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /// @dev Role identifier for accounts that can mint tokens
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @dev Role identifier for accounts that can upgrade the contract
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @dev Role identifier for accounts that can pause/unpause the contract
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @dev Role identifier for accounts that can update token prices
    bytes32 public constant PRICE_UPDATER_ROLE = keccak256("PRICE_UPDATER_ROLE");

    /// @dev Maximum price to prevent extreme values (100 ETH)
    uint256 public constant MAX_PRICE = 100 ether;

    /// @dev Minimum price to prevent zero division (0.000001 ETH)
    uint256 public constant MIN_PRICE = 1e12;

    /// @dev Maximum supply cap (1 billion tokens)
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 1e18;

    /// @dev Sell price percentage (98% of sale price)
    uint256 public constant SELL_PRICE_PERCENTAGE = 98;

    // =============================================================
    //                        STATE VARIABLES
    // =============================================================

    /// @dev Price to purchase 1 token in wei
    uint256 public salePrice;

    /// @dev Price to sell 1 token in wei (typically 98% of sale price)
    uint256 public sellPrice;

    /// @dev Whether token sale is currently active
    bool public saleActive;

    /// @dev Mapping to track used signature hashes to prevent replay attacks
    mapping(bytes32 => bool) public usedSignatures;

    // =============================================================
    //                            EVENTS
    // =============================================================

    /// @dev Emitted when sale price is updated
    event SalePriceUpdated(uint256 indexed newSalePrice, uint256 indexed newSellPrice);

    /// @dev Emitted when sale status changes
    event SaleStatusUpdated(bool indexed newStatus);

    /// @dev Emitted when tokens are purchased
    event TokensPurchased(address indexed buyer, uint256 tokenAmount, uint256 ethAmount);

    /// @dev Emitted when tokens are sold
    event TokensSold(address indexed seller, uint256 tokenAmount, uint256 ethAmount);

    /// @dev Emitted when excess ETH is withdrawn
    event ExcessWithdrawn(address indexed admin, uint256 amount);

    /// @dev Emitted when tokens are burned
    event TokensBurned(address indexed burner, uint256 amount);

    // =============================================================
    //                          MODIFIERS
    // =============================================================

    /**
     * @dev Ensures the total supply doesn't exceed the maximum cap
     * @param amount The amount to be minted
     */
    modifier withinSupplyCap(uint256 amount) {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds maximum supply");
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
     * @notice Initializes the CaDuCoinX token contract
     * @dev This function replaces the constructor for upgradeable contracts
     * @param defaultAdmin The address that will receive all initial roles
     * @param name The name of the token
     * @param symbol The symbol of the token
     */
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

        // Grant all roles to the default admin
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, defaultAdmin);
        _grantRole(UPGRADER_ROLE, defaultAdmin);
        _grantRole(PRICE_UPDATER_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, defaultAdmin);

        // Set initial configuration
        salePrice = 3300000000000; // 0.0000033 ETH
        sellPrice = (salePrice * SELL_PRICE_PERCENTAGE) / 100;
        saleActive = true;

        emit SalePriceUpdated(salePrice, sellPrice);
        emit SaleStatusUpdated(true);
    }

    // =============================================================
    //                      TOKEN FUNCTIONS
    // =============================================================

    /**
     * @notice Mints new tokens to the specified address
     * @dev Only accounts with MINTER_ROLE can call this function
     * @param to The address that will receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount)
    public
    onlyRole(MINTER_ROLE)
    withinSupplyCap(amount)
    {
        require(to != address(0), "Cannot mint to zero address");
        require(amount > 0, "Amount must be greater than zero");

        _mint(to, amount);
    }

    /**
     * @notice Burns tokens from the caller's balance
     * @dev Anyone can burn their own tokens
     * @param amount The amount of tokens to burn
     */
    function burn(uint256 amount) public {
        require(amount > 0, "Amount must be greater than zero");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance to burn");

        _burn(msg.sender, amount);
        emit TokensBurned(msg.sender, amount);
    }

    /**
     * @notice Burns tokens from a specific address (requires allowance)
     * @dev The caller must have sufficient allowance from the target address
     * @param from The address to burn tokens from
     * @param amount The amount of tokens to burn
     */
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

    /**
     * @notice Updates the sale and sell prices for token trading
     * @dev Only accounts with PRICE_UPDATER_ROLE can call this function
     * @param newSalePrice The new price for purchasing tokens (in wei)
     */
    function updateSalePrice(uint256 newSalePrice)
    public
    onlyRole(PRICE_UPDATER_ROLE)
    validPrice(newSalePrice)
    {
        salePrice = newSalePrice;
        sellPrice = (newSalePrice * SELL_PRICE_PERCENTAGE) / 100;

        emit SalePriceUpdated(salePrice, sellPrice);
    }

    /**
     * @notice Enables or disables token sales
     * @dev Only accounts with DEFAULT_ADMIN_ROLE can call this function
     * @param active Whether token sales should be active
     */
    function setSaleActive(bool active) public onlyRole(DEFAULT_ADMIN_ROLE) {
        saleActive = active;
        emit SaleStatusUpdated(active);
    }

    // =============================================================
    //                   TOKEN TRADING FUNCTIONS
    // =============================================================

    /**
     * @notice Allows users to purchase tokens with ETH
     * @dev Mints tokens based on the amount of ETH sent and current sale price
     * Requirements:
     * - Contract must not be paused
     * - Sale must be active
     * - Must send ETH with the transaction
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
     * @dev Burns tokens and sends ETH based on current sell price
     * @param tokenAmount The amount of tokens to sell
     * Requirements:
     * - Contract must not be paused
     * - Must have sufficient token balance
     * - Contract must have sufficient ETH balance
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

        _burn(msg.sender, tokenAmount);

        (bool success, ) = payable(msg.sender).call{value: ethToSend}("");
        require(success, "ETH transfer failed");

        emit TokensSold(msg.sender, tokenAmount, ethToSend);
    }

    /**
     * @notice Withdraws excess ETH from the contract
     * @dev Only withdraws ETH above the amount needed to back all circulating tokens
     * Only accounts with DEFAULT_ADMIN_ROLE can call this function
     */
    function withdraw() public onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        uint256 requiredBalanceWithdraw = requiredBalance();
        uint256 contractBalanceWithdraw = contractBalance();

        require(contractBalanceWithdraw > requiredBalanceWithdraw, "No excess balance to withdraw");

        uint256 amountToWithdraw = contractBalanceWithdraw - requiredBalanceWithdraw;

        (bool success, ) = payable(msg.sender).call{value: amountToWithdraw}("");
        require(success, "Withdrawal failed");

        emit ExcessWithdrawn(msg.sender, amountToWithdraw);
    }

    /**
     * @notice Emergency withdrawal function for admin
     * @dev Allows withdrawal of all ETH in emergency situations
     * Only accounts with DEFAULT_ADMIN_ROLE can call this function
     */
    function emergencyWithdraw() public onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        uint256 contractBalanceWithdraw = contractBalance();
        require(contractBalanceWithdraw > 0, "No balance to withdraw");

        (bool success, ) = payable(msg.sender).call{value: contractBalanceWithdraw}("");
        require(success, "Emergency withdrawal failed");

        emit ExcessWithdrawn(msg.sender, contractBalanceWithdraw);
    }

    // =============================================================
    //                    PAUSABLE FUNCTIONS
    // =============================================================

    /**
     * @notice Pauses all token transfers and trading functions
     * @dev Only accounts with PAUSER_ROLE can call this function
     */
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses all token transfers and trading functions
     * @dev Only accounts with PAUSER_ROLE can call this function
     */
    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // =============================================================
    //                     VIEW FUNCTIONS
    // =============================================================

    /**
     * @notice Calculates how many tokens can be purchased with a given amount of ETH
     * @param ethAmount The amount of ETH in wei
     * @return The number of tokens that can be purchased
     */
    function calculateTokensForEth(uint256 ethAmount) public view returns (uint256) {
        if (ethAmount == 0 || salePrice == 0) return 0;
        return (ethAmount * 10**decimals()) / salePrice;
    }

    /**
     * @notice Calculates how much ETH will be received for selling a given amount of tokens
     * @param tokenAmount The amount of tokens to sell
     * @return The amount of ETH that will be received
     */
    function calculateEthForTokens(uint256 tokenAmount) public view returns (uint256) {
        if (tokenAmount == 0 || sellPrice == 0) return 0;
        return (tokenAmount * sellPrice) / 10**decimals();
    }

    /**
     * @notice Returns the current contract ETH balance
     * @return The contract's ETH balance in wei
     */
    function contractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice Returns the required ETH balance to back all tokens
     * @return The required ETH balance in wei
     */
    function requiredBalance() public view returns (uint256) {
        return (totalSupply() * sellPrice) / 10**decimals();
    }

    /**
     * @notice Returns the excess ETH balance that can be withdrawn
     * @return The excess ETH balance in wei
     */
    function excessBalance() public view returns (uint256) {
        uint256 required = requiredBalance();
        uint256 current = contractBalance();
        return current > required ? current - required : 0;
    }

    // =============================================================
    //                    UPGRADE AUTHORIZATION
    // =============================================================

    /**
     * @notice Authorizes contract upgrades
     * @dev Only accounts with UPGRADER_ROLE can authorize upgrades
     * @param newImplementation The address of the new implementation contract
     */
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

    /**
     * @notice Override required by Solidity for multiple inheritance
     * @dev Calls the parent _update function from ERC20PausableUpgradeable
     */
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20PausableUpgradeable) {
        super._update(from, to, value);
    }

    // =============================================================
    //                    RECEIVE FUNCTION
    // =============================================================

    /**
     * @notice Allows the contract to receive ETH directly
     * @dev Automatically purchases tokens when ETH is sent directly to the contract
     */
    receive() external payable {
        if (msg.value > 0 && saleActive && !paused()) {
            uint256 tokensToMint = (msg.value * 10**decimals()) / salePrice;
            if (tokensToMint > 0 && totalSupply() + tokensToMint <= MAX_SUPPLY) {
                _mint(msg.sender, tokensToMint);
                emit TokensPurchased(msg.sender, tokensToMint, msg.value);
            }
        }
    }
}