// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./GameToken.sol";

interface IUniswapV3TwapOracle {
    function isValidPool(address pool, address tokenA, address tokenB) external view returns (bool);
    function quoteAtTwap(address pool, address baseToken, address quoteToken, uint128 baseAmount, uint32 secondsAgo)
        external view returns (uint256 quoteAmount, uint128 harmonicMeanLiquidity);
}

contract CaDuCoinXToken is Initializable, ERC20Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable, PausableUpgradeable {
    uint256 public constant DECIMALS = 18;
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * (10 ** DECIMALS);
    uint256 public constant INITIAL_SALE_PRICE = 3_300_000_000_000;
    uint256 public constant BUYBACK_PRICE_BPS = 9_800;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint32 public constant BUYBACK_TWAP_WINDOW = 30 minutes;
    uint256 public constant MIN_SALE_PRICE = 1e12;
    uint256 public constant MAX_SALE_PRICE = 100 ether;

    GameToken public gameToken;

    struct Item {
        uint256 id;
        string name;
        uint256 price;
    }

    struct Stake {
        uint256 amount;
        uint256 startTime;
        uint256 duration;
        uint256 rewardAmount;
    }

    mapping(address => Stake[]) private stakes;
    mapping(uint256 => Item) public items;
    uint256 public nextItemId;

    // APR em basis points: 600 = 6%, 420 = 4.2%, 1000 = 10%.
    uint256 public interestRate;
    uint256 public constant MIN_INTEREST_RATE = 420; // 4.2%
    uint256 public constant MAX_INTEREST_RATE = 1000; // 10%

    // Reserved rewards count against MAX_SUPPLY and cannot be consumed by owner minting.
    uint256 public reservedRewards;
    uint256 public salePrice;
    bool public saleActive;
    IUniswapV3TwapOracle public buybackOracle;
    address public buybackPool;
    address public buybackWeth;
    uint128 public minimumTwapLiquidity;
    uint256 public buybackBudget;
    bool public buybackActive;

    uint256 public constant THREE_MONTHS = 90 days;
    uint256 public constant SIX_MONTHS = 180 days;
    uint256 public constant NINE_MONTHS = 270 days;
    uint256 public constant TWELVE_MONTHS = 365 days;

    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);
    event Staked(address indexed user, uint256 amount, uint256 duration);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 rewards);
    event ItemPurchased(address indexed buyer, uint256 itemId, uint256 price);
    event InterestRateUpdated(uint256 newRate);
    event SalePriceUpdated(uint256 salePrice);
    event SaleStatusUpdated(bool active);
    event TokensPurchased(address indexed buyer, uint256 tokenAmount, uint256 ethAmount);
    event TokensSold(address indexed seller, uint256 tokenAmount, uint256 ethAmount);
    event EthDeposited(address indexed depositor, uint256 amount);
    event EthWithdrawn(address indexed recipient, uint256 amount);
    event BuybackPoolConfigured(address indexed pool, address indexed weth, uint128 minimumHarmonicLiquidity);
    event BuybackStatusUpdated(bool active);
    event BuybackBudgetAllocated(address indexed allocator, uint256 amount, uint256 totalBudget);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Inicializa o token e vincula o GameToken para funções de gamificação.
    function initialize(
        address _owner,
        string memory name,
        string memory symbol,
        address _gameToken,
        address _buybackOracle
    ) public initializer {
        __ERC20_init(name, symbol);
        __Ownable_init(_owner);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        __Pausable_init();

        require(_gameToken != address(0) && _gameToken.code.length > 0, "Invalid GameToken");
        require(_buybackOracle != address(0) && _buybackOracle.code.length > 0, "Invalid buyback oracle");
        gameToken = GameToken(_gameToken);
        buybackOracle = IUniswapV3TwapOracle(_buybackOracle);
        interestRate = 600;
        salePrice = INITIAL_SALE_PRICE;
        saleActive = true;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /// @notice Atualiza a taxa de juros, assegurando que esteja nos limites permitidos.
    function updateInterestRate(uint256 newRate) external onlyOwner {
        require(newRate >= MIN_INTEREST_RATE && newRate <= MAX_INTEREST_RATE, "Interest rate out of bounds");
        interestRate = newRate;
        emit InterestRateUpdated(newRate);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyOwner whenNotPaused {
        require(totalSupply() + reservedRewards + amount <= MAX_SUPPLY, "Exceeds available supply");
        _mint(to, amount);
        emit Minted(to, amount);
    }

    function updateSalePrice(uint256 newSalePrice) external onlyOwner {
        require(newSalePrice >= MIN_SALE_PRICE && newSalePrice <= MAX_SALE_PRICE, "Sale price out of bounds");
        salePrice = newSalePrice;
        emit SalePriceUpdated(newSalePrice);
    }

    function setSaleActive(bool active) external onlyOwner {
        saleActive = active;
        emit SaleStatusUpdated(active);
    }

    function purchaseTokens() external payable nonReentrant whenNotPaused {
        require(saleActive, "Token sale is not active");
        require(msg.value > 0, "Must send ETH to purchase tokens");

        uint256 amount = Math.mulDiv(msg.value, 10 ** DECIMALS, salePrice);
        require(amount > 0, "ETH amount too small");
        require(totalSupply() + reservedRewards + amount <= MAX_SUPPLY, "Exceeds available supply");

        _mint(msg.sender, amount);
        emit TokensPurchased(msg.sender, amount, msg.value);
    }

    function configureBuybackPool(address pool, address weth, uint128 minimumHarmonicLiquidity) external onlyOwner {
        require(!buybackActive, "Disable buybacks first");
        require(weth != address(0) && weth.code.length > 0, "Invalid WETH");
        require(minimumHarmonicLiquidity > 0, "Minimum liquidity is zero");
        require(buybackOracle.isValidPool(pool, address(this), weth), "Invalid Uniswap V3 pool");

        buybackPool = pool;
        buybackWeth = weth;
        minimumTwapLiquidity = minimumHarmonicLiquidity;
        emit BuybackPoolConfigured(pool, weth, minimumHarmonicLiquidity);
    }

    function setBuybackActive(bool active) external onlyOwner {
        if (active) {
            require(buybackPool != address(0), "Buyback pool not configured");
            (uint256 quote, uint128 harmonicLiquidity) = _quoteBuyback(10 ** DECIMALS);
            require(quote > 0, "Invalid TWAP quote");
            require(harmonicLiquidity >= minimumTwapLiquidity, "Insufficient TWAP liquidity");
        }
        buybackActive = active;
        emit BuybackStatusUpdated(active);
    }

    function allocateBuybackBudget(uint256 amount) external onlyOwner {
        require(amount > 0, "Budget amount is zero");
        uint256 balance = address(this).balance;
        require(balance >= buybackBudget, "Buyback budget exceeds balance");
        require(amount <= balance - buybackBudget, "Insufficient unallocated ETH");
        buybackBudget += amount;
        emit BuybackBudgetAllocated(msg.sender, amount, buybackBudget);
    }

    function sellTokens(uint256 amount, uint256 minEthOut) external nonReentrant whenNotPaused {
        require(buybackActive, "Buybacks are inactive");
        require(amount > 0, "Amount must be greater than zero");
        require(amount <= type(uint128).max, "Amount exceeds TWAP range");
        (uint256 ethAmount, uint128 harmonicLiquidity) = _quoteBuyback(amount);
        require(harmonicLiquidity >= minimumTwapLiquidity, "Insufficient TWAP liquidity");
        require(ethAmount > 0, "ETH amount too small");
        require(ethAmount >= minEthOut, "Below minimum ETH output");
        require(ethAmount <= buybackBudget, "Insufficient buyback budget");
        require(address(this).balance >= ethAmount, "Insufficient ETH balance");

        _burn(msg.sender, amount);
        buybackBudget -= ethAmount;

        (bool success, ) = payable(msg.sender).call{value: ethAmount}("");
        require(success, "ETH transfer failed");
        emit TokensSold(msg.sender, amount, ethAmount);
    }

    function _quoteBuyback(uint256 amount) private view returns (uint256 ethAmount, uint128 harmonicLiquidity) {
        require(buybackPool != address(0), "Buyback pool not configured");
        (uint256 twapQuote, uint128 meanLiquidity) = buybackOracle.quoteAtTwap(
            buybackPool,
            address(this),
            buybackWeth,
            uint128(amount),
            BUYBACK_TWAP_WINDOW
        );
        ethAmount = Math.mulDiv(twapQuote, BUYBACK_PRICE_BPS, BPS_DENOMINATOR);
        harmonicLiquidity = meanLiquidity;
    }

    function depositEth() external payable onlyOwner {
        require(msg.value > 0, "Must send ETH");
        emit EthDeposited(msg.sender, msg.value);
    }

    function withdrawUnallocatedEth(uint256 amount) external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(amount > 0, "Amount is zero");
        require(balance >= buybackBudget, "Buyback budget exceeds balance");
        require(amount <= balance - buybackBudget, "Cannot withdraw allocated ETH");
        address recipient = owner();

        (bool success, ) = payable(recipient).call{value: amount}("");
        require(success, "ETH withdrawal failed");
        emit EthWithdrawn(recipient, amount);
    }

    function unallocatedEth() external view returns (uint256) {
        uint256 balance = address(this).balance;
        return balance > buybackBudget ? balance - buybackBudget : 0;
    }

    function calculateTokensForEth(uint256 ethAmount) external view returns (uint256) {
        return Math.mulDiv(ethAmount, 10 ** DECIMALS, salePrice);
    }

    function calculateEthForTokens(uint256 tokenAmount) external view returns (uint256) {
        require(tokenAmount <= type(uint128).max, "Amount exceeds TWAP range");
        (uint256 quote, uint128 harmonicLiquidity) = _quoteBuyback(tokenAmount);
        require(harmonicLiquidity >= minimumTwapLiquidity, "Insufficient TWAP liquidity");
        return quote;
    }

    function burn(uint256 amount) public whenNotPaused {
        _burn(msg.sender, amount);
        emit Burned(msg.sender, amount);
    }

    // Delega a lógica de gamificação para o GameToken
    function levelUp(address player) public onlyOwner whenNotPaused {
        gameToken.levelUp(player);
    }

    function getPlayerData(address player) public view returns (GameToken.PlayerData memory) {
        return gameToken.getPlayerData(player);
    }

    /// @notice Adiciona um item ao marketplace.
    function addItem(string memory name, uint256 price) public onlyOwner whenNotPaused {
        items[nextItemId] = Item(nextItemId, name, price);
        nextItemId++;
    }

    /// @notice Permite a compra de um item, transferindo tokens do comprador para o contrato.
    function purchaseItem(uint256 itemId) public whenNotPaused {
        Item memory item = items[itemId];
        require(item.price > 0, "Item does not exist");
        require(balanceOf(msg.sender) >= item.price, "Insufficient balance");

        // Transferência segura com verificação implícita pela função _transfer
        _transfer(msg.sender, address(this), item.price);
        emit ItemPurchased(msg.sender, itemId, item.price);
    }

    /// @notice Realiza o stake de tokens por um período específico.
    function stake(uint256 amount, uint256 duration) public nonReentrant whenNotPaused {
        require(amount > 0, "Cannot stake 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance to stake");
        require(
            duration == THREE_MONTHS || duration == SIX_MONTHS || duration == NINE_MONTHS || duration == TWELVE_MONTHS,
            "Invalid staking duration"
        );

        uint256 reward = _calculateReward(amount, interestRate, duration);
        require(totalSupply() + reservedRewards + reward <= MAX_SUPPLY, "Insufficient reward capacity");

        // Transfere tokens do usuário para o contrato.
        _transfer(msg.sender, address(this), amount);

        stakes[msg.sender].push(Stake({
            amount: amount,
            startTime: block.timestamp,
            duration: duration,
            rewardAmount: reward
        }));
        reservedRewards += reward;

        emit Staked(msg.sender, amount, duration);
    }

    /// @notice Calcula as recompensas para um stake específico.
    /// @dev O cálculo é proporcional ao período de staking escolhido.
    function _calculateReward(uint256 amount, uint256 rate, uint256 duration) private pure returns (uint256) {
        // rate is expressed in basis points and duration is prorated over a 365-day year.
        return Math.mulDiv(amount, rate * duration, 10_000 * TWELVE_MONTHS);
    }

    /// @notice Libera um stake específico, transferindo o valor staked e mintando recompensas.
    function unstake(uint256 index) public nonReentrant {
        require(index < stakes[msg.sender].length, "Invalid stake index");

        Stake memory userStake = stakes[msg.sender][index];
        require(userStake.amount > 0, "No staked amount");
        require(block.timestamp >= userStake.startTime + userStake.duration, "Staking period not completed");

        // Remove state and release the reservation before applying the reserved reward.
        stakes[msg.sender][index] = stakes[msg.sender][stakes[msg.sender].length - 1];
        stakes[msg.sender].pop();
        reservedRewards -= userStake.rewardAmount;

        // Matured principal and its reserved reward remain withdrawable while paused.
        _transfer(address(this), msg.sender, userStake.amount);

        if (userStake.rewardAmount > 0) {
            _mint(msg.sender, userStake.rewardAmount);
            emit RewardsClaimed(msg.sender, userStake.rewardAmount);
        }

        emit Unstaked(msg.sender, userStake.amount);
    }

    /// @notice Retorna todas as stakes de um usuário.
    function getUserStakes(address user) public view returns (Stake[] memory) {
        return stakes[user];
    }
}
