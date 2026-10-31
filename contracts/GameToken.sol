// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";

contract GameToken is Ownable {
    struct PlayerData {
        uint256 level;
    }

    mapping(address => PlayerData) public players;

    event LevelUp(address indexed player, uint256 newLevel);

    constructor() Ownable(msg.sender) {}

    function levelUp(address player) external onlyOwner {
        require(player != address(0), "Invalid player address");
        players[player].level += 1;
        emit LevelUp(player, players[player].level);
    }

    function getPlayerData(address player) external view returns (PlayerData memory) {
        return players[player];
    }
}
