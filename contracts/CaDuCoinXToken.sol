// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract CaDuCoinXToken is Initializable, ERC20Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable, PausableUpgradeable {
    uint256 public constant DECIMALS = 10;
    uint256 public constant MAX_SUPPLY = 21000000 * (10 ** DECIMALS);

    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event InterestRateUpdated(uint256 newRate);
    event RewardsClaimed(address indexed user, uint256 rewards);

    struct Stake {
        uint256 amount;
        uint256 startTime;
    }

    mapping(address => Stake) private stakes;
    uint256 public interestRate;
    uint256 public constant MIN_INTEREST_RATE = 420;
    uint256 public constant MAX_INTEREST_RATE = 1000;

    modifier validAddress(address addr) {
        require(addr != address(0), "Invalid address");
        _;
    }

    function initialize(address _owner, string memory name, string memory symbol) public initializer validAddress(_owner) {
        __ERC20_init(name, symbol);
        __Ownable_init(_owner);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        __Pausable_init();

        _transferOwnership(_owner);
        interestRate = 600;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

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

    function stake(uint256 amount) public nonReentrant whenNotPaused {
        require(amount > 0, "Cannot stake 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance to stake");

        _transfer(msg.sender, address(this), amount);

        Stake storage stakeInfo = stakes[msg.sender];
        stakeInfo.amount += amount;
        stakeInfo.startTime = block.timestamp;

        emit Staked(msg.sender, amount);
    }

    function calculateRewards(address user) public view returns (uint256) {
        Stake storage stakeInfo = stakes[user];
        if (stakeInfo.amount == 0) {
            return 0;
        }
        uint256 duration = block.timestamp - stakeInfo.startTime; 
        uint256 interest = (stakeInfo.amount * interestRate * duration) / (365 days * 1000); 
        return interest;
    }

    function unstake() public nonReentrant whenNotPaused {
        Stake storage stakeInfo = stakes[msg.sender];
        require(stakeInfo.amount > 0, "No staked amount");

        uint256 rewards = calculateRewards(msg.sender);

        if (rewards > 0) {
            mint(msg.sender, rewards);
            emit RewardsClaimed(msg.sender, rewards);
        }

        _transfer(address(this), msg.sender, stakeInfo.amount);
        
        delete stakes[msg.sender]; 

        emit Unstaked(msg.sender, stakeInfo.amount);
    }

    function setInterestRate(uint256 newRate) public onlyOwner whenNotPaused {
        require(newRate >= MIN_INTEREST_RATE && newRate <= MAX_INTEREST_RATE, "Rate out of bounds");
        interestRate = newRate;
        emit InterestRateUpdated(newRate);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}
