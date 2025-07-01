// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IMarketplace
 * @dev Interface for unified marketplace implementations
 * @notice Defines the standard functions for asset trading across different marketplace types
 */
interface IMarketplace {
    /**
     * @notice Lists an asset for sale in the marketplace
     * @param name The name/description of the asset
     * @param price The price of the asset in tokens
     * @param category The category of the asset (e.g., "nft", "item")
     */
    function listAsset(string memory name, uint256 price, string memory category) external;

    /**
     * @notice Purchases a listed asset
     * @param assetId The ID of the asset to purchase
     */
    function purchaseAsset(uint256 assetId) external;

    /**
     * @notice Removes an asset from the marketplace
     * @param assetId The ID of the asset to delist
     */
    function delistAsset(uint256 assetId) external;

    /**
     * @notice Gets asset information by ID
     * @param assetId The ID of the asset
     * @return id Asset ID
     * @return name Asset name
     * @return price Asset price
     * @return seller Seller address
     * @return category Asset category
     */
    function getAsset(uint256 assetId) external view returns (
        uint256 id,
        string memory name,
        uint256 price,
        address seller,
        string memory category
    );
}