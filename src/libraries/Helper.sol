// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.14;
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/libraries/FixedPoint96.sol';
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import '@uniswap/v3-core/contracts/libraries/FullMath.sol';

import '@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol';
import '@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol';

import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import '@uniswap/v3-periphery/contracts/libraries/PositionValue.sol';

import '../RangePool.sol';

import './Conversion.sol';
import './RatioCalculator.sol';
import './Swapper.sol';
import './Math.sol';

library Helper {
  using PositionValue for INonfungiblePositionManager;
  using SafeMath for uint256;
  using SafeERC20 for ERC20;

  struct ConvertRatioParams {
    RangePool rangePool;
    address recipient;
    uint256 amount0;
    uint256 amount1;
    uint16 slippage;
  }

  uint16 public constant resolution = 10_000;

  function swap(Swapper.SwapParameters memory params) external returns (uint256 amountOut) {
    return Swapper.swap(params);
  }

  function convertToRatio(ConvertRatioParams memory params)
    external
    returns (uint256 converterAmount0, uint256 convertedAmount1)
  {
    (uint256 targetAmount0, uint256 targetAmount1) = RatioCalculator.calculateRatio(
      Conversion.sqrtPriceX96(params.rangePool.pool()),
      params.rangePool.pool().liquidity(),
      params.amount0,
      params.amount1,
      params.rangePool.lowerTick(),
      params.rangePool.upperTick(),
      ERC20(params.rangePool.pool().token0()).decimals()
    );

    converterAmount0 = params.amount0;
    convertedAmount1 = params.amount1;
    uint256 diff;

    diff = (params.amount0 > targetAmount0) ? params.amount0.sub(targetAmount0) : params.amount1.sub(targetAmount1);

    uint256 swaped = Swapper.swap(
      Swapper.SwapParameters({
        recipient: params.recipient,
        tokenIn: params.rangePool.pool().token0(),
        tokenOut: params.rangePool.pool().token1(),
        fee: params.rangePool.pool().fee(),
        amountIn: diff,
        slippage: params.slippage,
        oracleSeconds: params.rangePool.oracleSeconds()
      })
    );

    (converterAmount0, convertedAmount1) = (params.amount0 > targetAmount0)
      ? (converterAmount0.sub(diff), convertedAmount1.add(swaped))
      : (converterAmount0.add(swaped), convertedAmount1.sub(diff));

    assert(ERC20(params.rangePool.pool().token0()).balanceOf(params.recipient) >= converterAmount0);
    assert(ERC20(params.rangePool.pool().token1()).balanceOf(params.recipient) >= convertedAmount1);
  }

  function safeBalanceTransfer(
    address token,
    address sender,
    address recipient,
    uint256 amount
  ) external returns (uint256 amountSend) {
    uint256 balance = ERC20(token).balanceOf(sender);
    amountSend = (amount > balance) ? balance : amount;
    ERC20(token).safeTransfer(recipient, amountSend);
  }

  function fees(INonfungiblePositionManager positionManager, uint256 tokenId)
    external
    view
    returns (uint256 feeAmount0, uint256 feeAmount1)
  {
    (feeAmount0, feeAmount1) = positionManager.fees(tokenId);
  }

  function oracleSqrtPricex96(IUniswapV3Pool pool, uint32 oracleSeconds) external view returns (uint160) {
    return Conversion.oracleSqrtPricex96(pool, oracleSeconds);
  }

  function validateAndConvertLimits(
    IUniswapV3Pool pool,
    address token,
    uint256 lowerLimit,
    uint256 upperLimit
  ) external view returns (int24 lowerTick, int24 upperTick) {
    require(lowerLimit != upperLimit, 'Helper:LWR'); // Limits must be within a range

    (lowerLimit, upperLimit) = (lowerLimit < upperLimit) ? (lowerLimit, upperLimit) : (upperLimit, lowerLimit);

    if (lowerLimit == 0) upperLimit = 1;

    if (token != pool.token1()) {
      lowerLimit = priceToken0(lowerLimit, ERC20(pool.token0()).decimals(), ERC20(pool.token1()).decimals());
      upperLimit = priceToken0(upperLimit, ERC20(pool.token0()).decimals(), ERC20(pool.token1()).decimals());
    }

    (lowerTick, upperTick) = Conversion.convertLimitsToTicks(
      lowerLimit,
      upperLimit,
      pool.tickSpacing(),
      ERC20(pool.token0()).decimals()
    );
  }

  function getPoolAddress(
    address tokenA,
    address tokenB,
    uint24 fee,
    address uniswapFactory
  ) external pure returns (address) {
    return PoolAddress.computeAddress(uniswapFactory, PoolAddress.getPoolKey(tokenA, tokenB, fee));
  }

  function getAmountsForLiquidity(
    uint160 sqrtPriceX96,
    int24 lowerTick,
    int24 upperTick,
    uint128 liquidity
  ) external pure returns (uint256 expectedAmount0, uint256 expectedAmount1) {
    (expectedAmount0, expectedAmount1) = LiquidityAmounts.getAmountsForLiquidity(
      sqrtPriceX96,
      TickMath.getSqrtRatioAtTick(lowerTick),
      TickMath.getSqrtRatioAtTick(upperTick),
      liquidity
    );
  }

  function priceToken0(
    uint256 priceToken1,
    uint8 decimalsToken0,
    uint8 decimalsToken1
  ) internal pure returns (uint256) {
    if (priceToken1 == 0) priceToken1 = 1;
    return (10**(SafeMath.add(decimalsToken0, decimalsToken1))).div(priceToken1);
  }

  function getAmountsAtSqrtPrice(uint128 liquidity, uint160 sqrtPriceX96)
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
    uint16 slippage
  ) internal pure returns (uint256 amountAccepted) {
    amountAccepted = positive
      ? (amount.mul(slippage).div(resolution)).add(amount)
      : amount.sub(amount.mul(slippage).div(resolution));
  }
}
