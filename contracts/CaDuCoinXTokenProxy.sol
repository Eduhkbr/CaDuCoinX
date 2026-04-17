// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title CaDuCoinXTokenProxy
 * @dev Minimal secure proxy contract for CaDuCoinXToken using ERC1967 standard.
 * All calls are delegated to the implementation via ERC1967Proxy's fallback.
 * @author Eduhkbr
 */
contract CaDuCoinXTokenProxy is ERC1967Proxy {

    /// @dev Emitted when the proxy is deployed
    event ProxyDeployed(address indexed implementation, address indexed admin);

    /**
     * @notice Constructs the proxy with implementation and initialization data
     * @param implementation Address of the implementation contract (CaDuCoinXToken)
     * @param initData Encoded initialization data for the implementation contract
     */
    constructor(
        address implementation,
        bytes memory initData
    ) ERC1967Proxy(implementation, initData) {
        require(implementation != address(0), "Implementation cannot be zero address");
        require(initData.length > 0, "Initialization data cannot be empty");

        address admin;
        if (initData.length >= 36) {
            assembly {
                admin := mload(add(initData, 36))
            }
        }

        emit ProxyDeployed(implementation, admin);
    }

    /**
     * @notice Returns the current implementation address
     */
    function getImplementation() external view returns (address) {
        return _implementation();
    }

    /**
     * @notice Returns the proxy version
     */
    function getProxyVersion() external pure returns (string memory) {
        return "1.1.0";
    }
}
