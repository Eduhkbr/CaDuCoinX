// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./GameToken.sol";

contract CaDuCoinXToken is Initializable, ERC20Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable, PausableUpgradeable, IERC721Receiver {
    uint256 public constant DECIMALS = 18;
    uint256 public constant MAX_SUPPLY = 21000000 * (10 ** DECIMALS);

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

    struct NFTListing {
        address seller;
        uint256 price;
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
    mapping(address => mapping(uint256 => NFTListing)) public nftListings;

    address private _pendingNFTContract;
    address private _pendingNFTSeller;
    uint256 private _pendingNFTTokenId;

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
    event NFTPurchased(address indexed buyer, address nftContract, uint256 tokenId, uint256 price);
    event NFTListed(address indexed seller, address indexed nftContract, uint256 indexed tokenId, uint256 price);
    event NFTListingCancelled(address indexed seller, address indexed nftContract, uint256 indexed tokenId);
    event InterestRateUpdated(uint256 newRate);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Inicializa o token e vincula o GameToken para funções de gamificação.
    function initialize(address _owner, string memory name, string memory symbol, address _gameToken) public initializer {
        __ERC20_init(name, symbol);
        __Ownable_init(_owner);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        __Pausable_init();

        require(_gameToken != address(0) && _gameToken.code.length > 0, "Invalid GameToken");
        gameToken = GameToken(_gameToken);
        interestRate = 600;
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

    /// @notice Lista em escrow um NFT por um preço fixo em CDX.
    function listNFT(address nftContract, uint256 tokenId, uint256 price) external nonReentrant whenNotPaused {
        require(nftContract.code.length > 0, "Invalid NFT contract");
        require(price > 0, "Price must be positive");
        require(nftListings[nftContract][tokenId].seller == address(0), "NFT already listed");
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Not NFT owner");

        _pendingNFTContract = nftContract;
        _pendingNFTSeller = msg.sender;
        _pendingNFTTokenId = tokenId;
        IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);
        delete _pendingNFTContract;
        delete _pendingNFTSeller;
        delete _pendingNFTTokenId;

        require(IERC721(nftContract).ownerOf(tokenId) == address(this), "NFT escrow failed");
        nftListings[nftContract][tokenId] = NFTListing({seller: msg.sender, price: price});
        emit NFTListed(msg.sender, nftContract, tokenId, price);
    }

    /// @notice Compra uma listagem pelo preço definido pelo vendedor.
    function buyNFT(address nftContract, uint256 tokenId) external nonReentrant whenNotPaused {
        NFTListing memory listing = nftListings[nftContract][tokenId];
        require(listing.seller != address(0) && listing.price > 0, "NFT not listed");
        require(IERC721(nftContract).ownerOf(tokenId) == address(this), "NFT not in escrow");

        delete nftListings[nftContract][tokenId];
        _transfer(msg.sender, listing.seller, listing.price);
        IERC721(nftContract).safeTransferFrom(address(this), msg.sender, tokenId);
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "NFT transfer failed");
        emit NFTPurchased(msg.sender, nftContract, tokenId, listing.price);
    }

    /// @notice Cancela a listagem e devolve o NFT ao vendedor, inclusive durante pausa.
    function cancelNFTListing(address nftContract, uint256 tokenId) external nonReentrant {
        NFTListing memory listing = nftListings[nftContract][tokenId];
        require(listing.seller == msg.sender, "Not NFT seller");
        delete nftListings[nftContract][tokenId];
        IERC721(nftContract).safeTransferFrom(address(this), msg.sender, tokenId);
        emit NFTListingCancelled(msg.sender, nftContract, tokenId);
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata)
        external
        view
        override
        returns (bytes4)
    {
        require(
            msg.sender == _pendingNFTContract &&
            operator == address(this) &&
            from == _pendingNFTSeller &&
            tokenId == _pendingNFTTokenId,
            "Unsolicited NFT"
        );
        return IERC721Receiver.onERC721Received.selector;
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
