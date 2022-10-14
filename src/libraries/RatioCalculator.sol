// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import '@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol';

import './Conversions.sol';

library RatioCalculator {
  using SafeMath for uint256;

  function calculateRatio(
    uint160 sqrtPriceX96,
    uint128 liquidity,
    uint256 amount0,
    uint256 amount1,
    int24 lowerTick,
    int24 upperTick,
    uint8 decimalsToken0,
    uint16 precision
  ) internal view returns (uint256 amountRatioed0, uint256 amountRatioed1) {
    (uint256 amount0ConvertedToToken1, uint256 amount1) = _applyRatio(
      sqrtPriceX96,
      liquidity,
      amount0,
      amount1,
      lowerTick,
      upperTick,
      decimalsToken0,
      precision
    );

    amountRatioed0 = convert1ToToken0(sqrtPriceX96, amount0ConvertedToToken1, decimalsToken0);
    amountRatioed1 = amount1;
  }

  function convert0ToToken1(
    uint160 sqrtPriceX96,
    uint256 amount0,
    uint8 decimalsToken0
  ) internal pure returns (uint256 amount0ConvertedToToken1) {
    uint256 price = Conversions.sqrtPriceX96ToUint(sqrtPriceX96, decimalsToken0);
    amount0ConvertedToToken1 = amount0.mul(price).div(10**decimalsToken0);
  }

  function convert1ToToken0(
    uint160 sqrtPriceX96,
    uint256 amount1,
    uint8 decimalsToken0
  ) internal pure returns (uint256 amount1ConvertedToToken0) {
    uint256 price = Conversions.sqrtPriceX96ToUint(sqrtPriceX96, decimalsToken0);
    if (price == 0) return 0;
    amount1ConvertedToToken0 = amount1.mul(10**decimalsToken0).div(price);
  }

  function _applyRatio(
    uint160 sqrtPriceX96,
    uint128 liquidity,
    uint256 amount0,
    uint256 amount1,
    int24 lowerTick,
    int24 upperTick,
    uint8 decimalsToken0,
    uint16 precision
  ) private pure returns (uint256 ratioedAmount0InToken1, uint256 ratioedAmount1) {
    (uint256 ratio0, uint256 ratio1) = _getRatioForLiquidity(
      sqrtPriceX96,
      liquidity,
      lowerTick,
      upperTick,
      decimalsToken0,
      precision
    );

    uint256 sumAmountInToken1 = convert0ToToken1(sqrtPriceX96, amount0, decimalsToken0).add(amount1);
    ratioedAmount0InToken1 = sumAmountInToken1.mul(ratio0).div(precision);
    ratioedAmount1 = sumAmountInToken1.mul(ratio1).div(precision);
  }

  function _getRatioForLiquidity(
    uint160 sqrtPriceX96,
    uint128 liquidity,
    int24 lowerTick,
    int24 upperTick,
    uint8 decimalsToken0,
    uint16 precision
  ) private pure returns (uint256 ratioToken0, uint256 ratioToken1) {
    (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
      sqrtPriceX96,
      TickMath.getSqrtRatioAtTick(lowerTick),
      TickMath.getSqrtRatioAtTick(upperTick),
      liquidity
    );

    uint256 amount0ConvertedToToken1 = convert0ToToken1(sqrtPriceX96, amount0, decimalsToken0);
    uint256 sum = amount0ConvertedToToken1.add(amount1);
    if (sum == 0) sum = 1;
    ratioToken0 = amount0ConvertedToToken1.mul(precision).div(sum);
    ratioToken1 = amount1.mul(precision).div(sum);
  }
}
