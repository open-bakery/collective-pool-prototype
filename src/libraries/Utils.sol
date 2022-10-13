// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.14;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

import '@uniswap/v3-core/contracts/libraries/FixedPoint96.sol';
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';

import '@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol';

import './Conversions.sol';

library Utils {
  using SafeMath for uint256;

  function getPoolAddress(
    address tokenA,
    address tokenB,
    uint24 fee,
    address uniswapFactory
  ) internal pure returns (address) {
    return PoolAddress.computeAddress(uniswapFactory, PoolAddress.getPoolKey(tokenA, tokenB, fee));
  }

  function orderTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
    require(tokenA != tokenB);
    (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
  }

  function priceToken0(
    uint256 priceToken1,
    uint8 decimalsToken0,
    uint8 decimalsToken1
  ) internal pure returns (uint256) {
    if (priceToken1 == 0) priceToken1 = 1;
    return (10**(SafeMath.add(decimalsToken0, decimalsToken1))).div(priceToken1);
  }

  function convertTickToPriceUint(int24 tick, uint8 decimalsToken0) internal pure returns (uint256) {
    return Conversions.sqrtPriceX96ToUint(TickMath.getSqrtRatioAtTick(tick), decimalsToken0);
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

  function getAmounts(uint128 liquidity, uint160 sqrtPriceX96)
    internal
    pure
    returns (uint256 amount0, uint256 amount1)
  {
    amount0 = FullMath.mulDiv(liquidity, FixedPoint96.Q96, sqrtPriceX96);
    amount1 = FullMath.mulDiv(liquidity, sqrtPriceX96, FixedPoint96.Q96);
  }

  function applySlippageTolerance(
    bool positive,
    uint256 amount,
    uint16 slippage,
    uint16 resolution
  ) internal pure returns (uint256 amountAccepted) {
    amountAccepted = positive
      ? (amount.mul(slippage).div(resolution)).add(amount)
      : amount.sub(amount.mul(slippage).div(resolution));
  }

  function validateAndConvertLimits(
    IUniswapV3Pool pool,
    address token,
    uint256 lowerLimit,
    uint256 upperLimit
  ) internal returns (int24 lowerTick, int24 upperTick) {
    require(lowerLimit != upperLimit, 'RangePool: Limits must be within a range');

    (lowerLimit, upperLimit) = (lowerLimit < upperLimit) ? (lowerLimit, upperLimit) : (upperLimit, lowerLimit);

    if (lowerLimit == 0) upperLimit = 1;

    if (token != pool.token1()) {
      lowerLimit = Utils.priceToken0(lowerLimit, ERC20(pool.token0()).decimals(), ERC20(pool.token1()).decimals());
      upperLimit = Utils.priceToken0(upperLimit, ERC20(pool.token0()).decimals(), ERC20(pool.token1()).decimals());
    }

    (lowerTick, upperTick) = convertLimitsToTicks(
      lowerLimit,
      upperLimit,
      pool.tickSpacing(),
      ERC20(pool.token0()).decimals()
    );
  }

  function _getValidatedTickNumber(
    uint256 price,
    uint8 decimalsToken0,
    int24 tickSpacing
  ) private pure returns (int24) {
    int24 tick = TickMath.getTickAtSqrtRatio(Conversions.uintToSqrtPriceX96(price, decimalsToken0));
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
