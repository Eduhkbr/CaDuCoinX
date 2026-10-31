// SPDX-License-Identifier: MIT
pragma solidity ^0.8.38;

interface ICdxBuyback {
    function sellTokens(uint256 amount, uint256 minEthOut) external;
}

contract RejectingBuybackSeller {
    function sell(address token, uint256 amount, uint256 minEthOut) external {
        ICdxBuyback(token).sellTokens(amount, minEthOut);
    }

    receive() external payable {
        revert("Reject ETH");
    }
}
