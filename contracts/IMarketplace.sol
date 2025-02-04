// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IMarketplace {
    function listAsset(string memory _name, uint256 _price, string memory _category) external;
    function purchaseAsset(uint256 assetId) external;
    function delistAsset(uint256 assetId) external;
}