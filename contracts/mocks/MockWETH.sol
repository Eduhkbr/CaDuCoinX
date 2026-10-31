// SPDX-License-Identifier: MIT
pragma solidity ^0.8.38;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockWETH is ERC20 {
    constructor() ERC20("Wrapped Ether", "WETH") {}
}
