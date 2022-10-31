// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.14;
pragma abicoder v2;

import '@openzeppelin/contracts/math/SafeMath.sol';

import '@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol';
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';

import './Conversion.sol';
import './Helper.sol';

library RatioCalculator {
  using SafeMath for uint256;
  using SafeMath for uint128;

  function calculateRatio(
    uint160 sqrtPriceX96,
    uint128 liquidity,
    uint256 amount0,
    uint256 amount1,
    int24 lowerTick,
    int24 upperTick,
    uint8 decimalsToken0
  ) internal pure returns (uint256 amountRatioed0, uint256 amountRatioed1) {
    (uint256 ratioedAmount0ConvertedToToken1, uint256 ratioedAmount1) = _applyRatio(
      sqrtPriceX96,
      liquidity,
      amount0,
      amount1,
      lowerTick,
      upperTick,
      decimalsToken0
    );

    amountRatioed0 = Conversion.convert1ToToken0(sqrtPriceX96, ratioedAmount0ConvertedToToken1, decimalsToken0);
    amountRatioed1 = ratioedAmount1;
  }

  function _applyRatio(
    uint160 sqrtPriceX96,
    uint128 liquidity,
    uint256 amount0,
    uint256 amount1,
    int24 lowerTick,
    int24 upperTick,
    uint8 decimalsToken0
  ) private pure returns (uint256 ratioedAmount0InToken1, uint256 ratioedAmount1) {
    (uint256 ratio0, uint256 ratio1) = _getRatioForLiquidity(
      sqrtPriceX96,
      liquidity,
      lowerTick,
      upperTick,
      decimalsToken0
    );

    uint256 sumAmountInToken1 = Conversion.convert0ToToken1(sqrtPriceX96, amount0, decimalsToken0).add(amount1);
    ratioedAmount0InToken1 = sumAmountInToken1.mul(ratio0).div(Helper.resolution);
    ratioedAmount1 = sumAmountInToken1.mul(ratio1).div(Helper.resolution);
  }

  function _getRatioForLiquidity(
    uint160 sqrtPriceX96,
    uint128 liquidity,
    int24 lowerTick,
    int24 upperTick,
    uint8 decimalsToken0
  ) private pure returns (uint256 ratioToken0, uint256 ratioToken1) {
    (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
      sqrtPriceX96,
      TickMath.getSqrtRatioAtTick(lowerTick),
      TickMath.getSqrtRatioAtTick(upperTick),
      liquidity
    );

    uint256 amount0ConvertedToToken1 = Conversion.convert0ToToken1(sqrtPriceX96, amount0, decimalsToken0);
    uint256 sum = amount0ConvertedToToken1.add(amount1);
    if (sum == 0) sum = 1;
    ratioToken0 = amount0ConvertedToToken1.mul(Helper.resolution).div(sum);
    ratioToken1 = amount1.mul(Helper.resolution).div(sum);
  }
}
