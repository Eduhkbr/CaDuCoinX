// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0 <0.8.0;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";

/// @notice Read-only adapter for validated Uniswap V3 pools and TWAP quotes.
contract UniswapV3TwapOracle {
    address public immutable factory;

    constructor(address factory_) {
        uint256 factoryCodeSize;
        assembly { factoryCodeSize := extcodesize(factory_) }
        require(factory_ != address(0) && factoryCodeSize > 0, "Invalid Uniswap factory");
        factory = factory_;
    }

    function isValidPool(address pool, address tokenA, address tokenB) external view returns (bool) {
        _validatePool(pool, tokenA, tokenB);
        return true;
    }

    function quoteAtTwap(
        address pool,
        address baseToken,
        address quoteToken,
        uint128 baseAmount,
        uint32 secondsAgo
    ) external view returns (uint256 quoteAmount, uint128 harmonicMeanLiquidity) {
        _validatePool(pool, baseToken, quoteToken);
        require(baseAmount > 0, "Base amount is zero");
        (int24 arithmeticMeanTick, uint128 meanLiquidity) = OracleLibrary.consult(pool, secondsAgo);
        quoteAmount = OracleLibrary.getQuoteAtTick(arithmeticMeanTick, baseAmount, baseToken, quoteToken);
        harmonicMeanLiquidity = meanLiquidity;
    }

    function _validatePool(address pool, address tokenA, address tokenB) private view {
        uint256 poolCodeSize;
        assembly { poolCodeSize := extcodesize(pool) }
        require(pool != address(0) && poolCodeSize > 0, "Invalid Uniswap pool");
        require(tokenA != address(0) && tokenB != address(0) && tokenA != tokenB, "Invalid token pair");

        IUniswapV3Pool uniswapPool = IUniswapV3Pool(pool);
        address token0 = uniswapPool.token0();
        address token1 = uniswapPool.token1();
        require(
            (token0 == tokenA && token1 == tokenB) || (token0 == tokenB && token1 == tokenA),
            "Pool token pair mismatch"
        );
        require(uniswapPool.factory() == factory, "Pool factory mismatch");
        require(IUniswapV3Factory(factory).getPool(token0, token1, uniswapPool.fee()) == pool, "Unrecognized Uniswap pool");
    }
}
