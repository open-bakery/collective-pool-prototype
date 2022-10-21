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
import '@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol';
import '@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol';

import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import '@uniswap/v3-periphery/contracts/libraries/PositionValue.sol';

import '../RangePool.sol';
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

  uint16 private constant resolution = 10_000;

  function swap(Swapper.SwapParameters memory params) external returns (uint256 amountOut) {
    return Swapper.swap(params);
  }

  function fees(INonfungiblePositionManager positionManager, uint256 tokenId)
    external
    view
    returns (uint256 feeAmount0, uint256 feeAmount1)
  {
    (feeAmount0, feeAmount1) = positionManager.fees(tokenId);
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

  function convertToRatio(ConvertRatioParams memory params)
    external
    returns (uint256 converterAmount0, uint256 convertedAmount1)
  {
    (uint256 targetAmount0, uint256 targetAmount1) = calculateRatio(
      sqrtPriceX96(params.rangePool.pool()),
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

    (lowerTick, upperTick) = convertLimitsToTicks(
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

    amountRatioed0 = convert1ToToken0(sqrtPriceX96, ratioedAmount0ConvertedToToken1, decimalsToken0);
    amountRatioed1 = ratioedAmount1;
  }

  function tickToPriceUint(int24 tick, uint8 decimalsToken0) internal pure returns (uint256) {
    return convertTickToPriceUint(tick, decimalsToken0);
  }

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

  function priceToken0(
    uint256 priceToken1,
    uint8 decimalsToken0,
    uint8 decimalsToken1
  ) internal pure returns (uint256) {
    if (priceToken1 == 0) priceToken1 = 1;
    return (10**(SafeMath.add(decimalsToken0, decimalsToken1))).div(priceToken1);
  }

  function convert0ToToken1(
    uint160 sqrtPriceX96,
    uint256 amount0,
    uint8 decimalsToken0
  ) internal pure returns (uint256 amount0ConvertedToToken1) {
    uint256 price = sqrtPriceX96ToUint(sqrtPriceX96, decimalsToken0);
    amount0ConvertedToToken1 = amount0.mul(price).div(10**decimalsToken0);
  }

  function convert1ToToken0(
    uint160 sqrtPriceX96,
    uint256 amount1,
    uint8 decimalsToken0
  ) internal pure returns (uint256 amount1ConvertedToToken0) {
    uint256 price = sqrtPriceX96ToUint(sqrtPriceX96, decimalsToken0);
    if (price == 0) return 0;
    amount1ConvertedToToken0 = amount1.mul(10**decimalsToken0).div(price);
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

  function orderTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
    require(tokenA != tokenB, 'Helper:ET'); // Equal Tokens
    (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
  }

  function convertTickToPriceUint(int24 tick, uint8 decimalsToken0) internal pure returns (uint256) {
    return sqrtPriceX96ToUint(TickMath.getSqrtRatioAtTick(tick), decimalsToken0);
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
    uint16 slippage
  ) internal pure returns (uint256 amountAccepted) {
    amountAccepted = positive
      ? (amount.mul(slippage).div(resolution)).add(amount)
      : amount.sub(amount.mul(slippage).div(resolution));
  }

  // Uniswap's default is price=y/x, this means that the sqrtPriceX96 from a pool contract
  // will always be of the price of token1 relative to token0.
  function sqrtPriceX96ToUint(uint160 sqrtPriceX96, uint8 decimalsToken0) internal pure returns (uint256) {
    uint256 numerator1 = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);
    uint256 numerator2 = 10**decimalsToken0;
    return FullMath.mulDiv(numerator1, numerator2, 1 << 192);
  }

  // Uniswap's default is price=y/x, this means that the price one gets is always the amount of token1 relative to token 0.
  function uintToSqrtPriceX96(uint256 priceToken1, uint8 decimalsToken0) internal pure returns (uint160) {
    uint256 ratioX192 = FullMath.mulDiv(priceToken1, 1 << 192, 10**decimalsToken0);
    return uint160(Math.sqrt(ratioX192));
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

    uint256 sumAmountInToken1 = convert0ToToken1(sqrtPriceX96, amount0, decimalsToken0).add(amount1);
    ratioedAmount0InToken1 = sumAmountInToken1.mul(ratio0).div(resolution);
    ratioedAmount1 = sumAmountInToken1.mul(ratio1).div(resolution);
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

    uint256 amount0ConvertedToToken1 = convert0ToToken1(sqrtPriceX96, amount0, decimalsToken0);
    uint256 sum = amount0ConvertedToToken1.add(amount1);
    if (sum == 0) sum = 1;
    ratioToken0 = amount0ConvertedToToken1.mul(resolution).div(sum);
    ratioToken1 = amount1.mul(resolution).div(sum);
  }
}
