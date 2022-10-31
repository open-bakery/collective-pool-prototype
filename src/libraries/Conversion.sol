// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.14;
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import '@uniswap/v3-core/contracts/libraries/FullMath.sol';

import '@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol';

import './Helper.sol';
import './Math.sol';

library Conversion {
  using SafeMath for uint256;

  function sqrtPriceX96(IUniswapV3Pool pool) internal view returns (uint160 _sqrtPriceX96) {
    (_sqrtPriceX96, , , , , , ) = pool.slot0();
  }

  function oracleSqrtPricex96(IUniswapV3Pool pool, uint32 elapsedSeconds) internal view returns (uint160) {
    (int24 arithmeticMeanTick, ) = OracleLibrary.consult(address(pool), elapsedSeconds);
    return TickMath.getSqrtRatioAtTick(arithmeticMeanTick);
  }

  function uintPrice(IUniswapV3Pool pool) internal view returns (uint256) {
    return sqrtPriceX96ToUint(sqrtPriceX96(pool), ERC20(pool.token0()).decimals());
  }

  function oracleUintPrice(IUniswapV3Pool pool, uint32 elapsedSeconds) internal view returns (uint256) {
    return sqrtPriceX96ToUint(oracleSqrtPricex96(pool, elapsedSeconds), ERC20(pool.token0()).decimals());
  }

  // Uniswap's default is price=y/x, this means that the sqrtPriceX96 from a pool contract
  // will always be of the price of token1 relative to token0.
  function sqrtPriceX96ToUint(uint160 _sqrtPriceX96, uint8 decimalsToken0) internal pure returns (uint256) {
    uint256 numerator1 = uint256(_sqrtPriceX96) * uint256(_sqrtPriceX96);
    uint256 numerator2 = 10**decimalsToken0;
    return FullMath.mulDiv(numerator1, numerator2, 1 << 192);
  }

  // Uniswap's default is price=y/x, this means that the price one gets is always the amount of token1 relative to token 0.
  function uintToSqrtPriceX96(uint256 priceToken1, uint8 decimalsToken0) internal pure returns (uint160) {
    uint256 ratioX192 = FullMath.mulDiv(priceToken1, 1 << 192, 10**decimalsToken0);
    return uint160(Math.sqrt(ratioX192));
  }

  function convertTickToPriceUint(int24 tick, uint8 decimalsToken0) internal pure returns (uint256) {
    return sqrtPriceX96ToUint(TickMath.getSqrtRatioAtTick(tick), decimalsToken0);
  }

  function convertLimitsToTicks(
    uint256 lowerLimit,
    uint256 upperLimit,
    int24 tickSpacing,
    uint8 decimalsToken0
  ) internal pure returns (int24 lowerTick, int24 upperTick) {
    int24 tickL = _getValidatedTickNumber(lowerLimit, decimalsToken0, tickSpacing);
    int24 tickU = _getValidatedTickNumber(upperLimit, decimalsToken0, tickSpacing);
    (lowerTick, upperTick) = _orderTicks(tickL, tickU);
  }

  function convert0ToToken1(
    uint160 _sqrtPriceX96,
    uint256 amount0,
    uint8 decimalsToken0
  ) internal pure returns (uint256 amount0ConvertedToToken1) {
    uint256 price = sqrtPriceX96ToUint(_sqrtPriceX96, decimalsToken0);
    amount0ConvertedToToken1 = amount0.mul(price).div(10**decimalsToken0);
  }

  function convert1ToToken0(
    uint160 _sqrtPriceX96,
    uint256 amount1,
    uint8 decimalsToken0
  ) internal pure returns (uint256 amount1ConvertedToToken0) {
    uint256 price = sqrtPriceX96ToUint(_sqrtPriceX96, decimalsToken0);
    if (price == 0) return 0;
    amount1ConvertedToToken0 = amount1.mul(10**decimalsToken0).div(price);
  }

  function _getValidatedTickNumber(
    uint256 price,
    uint8 decimalsToken0,
    int24 tickSpacing
  ) private pure returns (int24) {
    int24 tick = TickMath.getTickAtSqrtRatio(uintToSqrtPriceX96(price, decimalsToken0));
    return _validateTick(tick, tickSpacing);
  }

  function _validateTick(int24 tick, int24 tickSpacing) private pure returns (int24) {
    if (tickSpacing == 0) tickSpacing = 1;
    return (tick / tickSpacing) * tickSpacing;
  }

  function _orderTicks(int24 tick0, int24 tick1) private pure returns (int24 tickLower, int24 tickUpper) {
    (tickLower, tickUpper) = tick1 < tick0 ? (tick1, tick0) : (tick0, tick1);
  }
}
