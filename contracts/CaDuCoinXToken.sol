// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./GameToken.sol";

contract CaDuCoinXToken is Initializable, ERC20Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable, PausableUpgradeable {
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
    }

    mapping(address => Stake[]) private stakes;
    mapping(uint256 => Item) public items;
    uint256 public nextItemId;

    // Taxa de juros base (por mil, ex: 600 = 6%)
    uint256 public interestRate;
    uint256 public constant MIN_INTEREST_RATE = 420; // 4.2%
    uint256 public constant MAX_INTEREST_RATE = 1000; // 10%

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
    event InterestRateUpdated(uint256 newRate);

    /// @notice Inicializa o token e vincula o GameToken para funções de gamificação.
    function initialize(address _owner, string memory name, string memory symbol, address _gameToken) public initializer {
        __ERC20_init(name, symbol);
        __Ownable_init(_owner);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        __Pausable_init();

        _transferOwnership(_owner);
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

    function mint(address to, uint256 amount) public onlyOwner whenNotPaused {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds maximum supply");
        _mint(to, amount);
        emit Minted(to, amount);
    }

    function burn(address from, uint256 amount) public onlyOwner whenNotPaused {
        require(balanceOf(from) >= amount, "Insufficient balance to burn");
        _burn(from, amount);
        emit Burned(from, amount);
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

    /// @notice Compra um NFT utilizando tokens. Verifica o sucesso da transferência.
    function purchaseNFT(address nftContract, uint256 tokenId, uint256 price) public whenNotPaused {
        require(balanceOf(msg.sender) >= price, "Insufficient balance");
        _transfer(msg.sender, address(this), price);
        
        // Valida se o contrato realmente possui o NFT
        require(IERC721(nftContract).ownerOf(tokenId) == address(this), "Contract does not own the NFT");

        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
        
        // Verifica se a transferência ocorreu corretamente
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "NFT transfer failed");
        emit NFTPurchased(msg.sender, nftContract, tokenId, price);
    }

    /// @notice Realiza o stake de tokens por um período específico.
    function stake(uint256 amount, uint256 duration) public nonReentrant whenNotPaused {
        require(amount > 0, "Cannot stake 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance to stake");
        require(
            duration == THREE_MONTHS || duration == SIX_MONTHS || duration == NINE_MONTHS || duration == TWELVE_MONTHS,
            "Invalid staking duration"
        );

        // Transfere tokens do usuário para o contrato.
        _transfer(msg.sender, address(this), amount);

        stakes[msg.sender].push(Stake({
            amount: amount,
            startTime: block.timestamp,
            duration: duration
        }));

        emit Staked(msg.sender, amount, duration);
    }

    /// @notice Calcula as recompensas para um stake específico.
    /// @dev O cálculo é proporcional ao período de staking escolhido.
    function calculateRewardForStake(Stake memory stakeInfo) internal view returns (uint256) {
        // Cálculo proporcional considerando o stake.duration em relação a TWELVE_MONTHS.
        uint256 proportionalRate = (interestRate * stakeInfo.duration) / TWELVE_MONTHS; 
        return (stakeInfo.amount * proportionalRate) / 1000;
    }

    /// @notice Libera um stake específico, transferindo o valor staked e mintando recompensas.
    function unstake(uint256 index) public nonReentrant whenNotPaused {
        require(index < stakes[msg.sender].length, "Invalid stake index");

        Stake memory userStake = stakes[msg.sender][index];
        require(userStake.amount > 0, "No staked amount");
        require(block.timestamp >= userStake.startTime + userStake.duration, "Staking period not completed");

        // Calcula a recompensa para o stake em questão.
        uint256 reward = calculateRewardForStake(userStake);

        // Transfere o valor staked de volta
        _transfer(address(this), msg.sender, userStake.amount);

        // Caso haja recompensa, realiza o mint
        if (reward > 0) {
            mint(msg.sender, reward);
            emit RewardsClaimed(msg.sender, reward);
        }

        // Remove o stake liberado da lista sem causar contagem duplicada.
        stakes[msg.sender][index] = stakes[msg.sender][stakes[msg.sender].length - 1];
        stakes[msg.sender].pop();

        emit Unstaked(msg.sender, userStake.amount);
    }

    /// @notice Retorna todas as stakes de um usuário.
    function getUserStakes(address user) public view returns (Stake[] memory) {
        return stakes[user];
    }
}
