// SPDX-License-Identifier: MIT
pragma solidity ^0.8.38;

contract MockUniswapV3Pool {
    address public immutable factory;
    address public immutable token0;
    address public immutable token1;
    uint24 public immutable fee;
    int24 public tick;
    uint128 public harmonicLiquidity;
    uint128 private currentLiquidityValue;
    uint32 public historySeconds;

    constructor(address factory_, address token0_, address token1_, uint24 fee_) {
        factory = factory_;
        token0 = token0_;
        token1 = token1_;
        fee = fee_;
        harmonicLiquidity = 1_000_000;
        currentLiquidityValue = 1_000_000;
        historySeconds = 30 minutes;
    }

    function setOracle(int24 tick_, uint128 liquidity_, uint32 historySeconds_) external {
        tick = tick_;
        harmonicLiquidity = liquidity_;
        currentLiquidityValue = liquidity_;
        historySeconds = historySeconds_;
    }

    function setCurrentLiquidity(uint128 liquidity_) external {
        currentLiquidityValue = liquidity_;
    }

    function liquidity() external view returns (uint128) {
        return currentLiquidityValue;
    }

    function observe(uint32[] calldata secondsAgos)
        external view returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s)
    {
        tickCumulatives = new int56[](secondsAgos.length);
        secondsPerLiquidityCumulativeX128s = new uint160[](secondsAgos.length);
        for (uint256 i; i < secondsAgos.length; ++i) {
            require(secondsAgos[i] <= historySeconds, "Insufficient history");
            tickCumulatives[i] = int56(tick) * int56(uint56(secondsAgos[i]));
            uint160 elapsed = uint160((uint256(secondsAgos[i]) << 128) / harmonicLiquidity);
            secondsPerLiquidityCumulativeX128s[i] = elapsed == 0 ? 0 : type(uint160).max - elapsed + 1;
        }
    }
}
