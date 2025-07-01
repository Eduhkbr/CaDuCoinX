// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title CaDuCoinXTokenProxy
 * @dev Secure proxy contract for CaDuCoinXToken using ERC1967 standard
 * @notice This proxy enables upgradeable functionality for the CaDuCoinX token
 * @author Eduhkbr
 */
contract CaDuCoinXTokenProxy is ERC1967Proxy {

    // =============================================================
    //                            EVENTS
    // =============================================================

    /// @dev Emitted when the proxy is successfully deployed
    event ProxyDeployed(address indexed implementation, address indexed admin);

    /// @dev Emitted when ETH is attempted to be sent to the proxy
    event EtherRejected(address indexed sender, uint256 amount);

    // =============================================================
    //                        CONSTRUCTOR
    // =============================================================

    /**
     * @notice Constructs the proxy contract with implementation and initialization data
     * @param implementation Address of the implementation contract (CaDuCoinXToken)
     * @param initData Encoded initialization data for the implementation contract
     */
    constructor(
        address implementation,
        bytes memory initData
    ) ERC1967Proxy(implementation, initData) {
        require(implementation != address(0), "Implementation cannot be zero address");
        require(initData.length > 0, "Initialization data cannot be empty");

        // Extract admin address from initialization data for event
        address admin;
        if (initData.length >= 36) { // 4 bytes selector + 32 bytes address
            assembly {
                admin := mload(add(initData, 36))
            }
        }

        emit ProxyDeployed(implementation, admin);
    }

    // =============================================================
    //                    PROXY FUNCTIONS
    // =============================================================

    /**
     * @notice Returns the current implementation address
     * @return impl The address of the current implementation contract
     */
    function getImplementation() external view returns (address impl) {
        impl = _implementation();
    }

    /**
     * @notice Checks if the proxy has been properly initialized
     * @return initialized True if the contract appears to be initialized
     */
    function isInitialized() external view returns (bool initialized) {
        address impl = _implementation();
        if (impl == address(0)) {
            return false;
        }

        // Try to call totalSupply() to check if initialized
        (bool success, bytes memory result) = impl.staticcall(
            abi.encodeWithSignature("totalSupply()")
        );

        return success && result.length > 0;
    }

    /**
     * @notice Returns comprehensive proxy information
     * @return implementation Current implementation address
     * @return initialized Whether the proxy appears to be initialized
     */
    function getProxyInfo() external view returns (
        address implementation,
        bool initialized
    ) {
        implementation = _implementation();
        initialized = this.isInitialized();
    }

    // =============================================================
    //                    SECURITY FUNCTIONS
    // =============================================================

    /**
     * @notice Rejects all direct ETH transfers to the proxy
     */
    receive() external payable {
        emit EtherRejected(msg.sender, msg.value);
        revert("Proxy does not accept direct ETH transfers");
    }

    /**
     * @notice Rejects all fallback calls with ETH
     */
    fallback() external payable override {
        if (msg.value > 0) {
            emit EtherRejected(msg.sender, msg.value);
            revert("Proxy does not accept ETH via fallback");
        }
        // For non-payable calls, delegate to implementation
        _delegate(_implementation());
    }

    /**
     * @notice Returns the proxy version
     */
    function getProxyVersion() external pure returns (string memory) {
        return "1.0.0";
    }
}
