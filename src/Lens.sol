// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;
import '@uniswap/v3-periphery/contracts/libraries/PositionValue.sol';

import './libraries/Conversion.sol';
import './libraries/RatioCalculator.sol';
import './RangePoolFactory.sol';
import './RangePool.sol';
import './LiquidityProviderToken.sol';
import './libraries/Helper.sol';

contract Lens {
  using SafeMath for uint256;
  using PositionValue for INonfungiblePositionManager;

  function principal(RangePool rp) external view returns (uint256 amount0, uint256 amount1) {
    (amount0, amount1) = rp.positionManager().principal(rp.tokenId(), Conversion.sqrtPriceX96(rp.pool()));
  }

  function unclaimedFees(RangePool rp) external view returns (uint256 amount0, uint256 amount1) {
    (amount0, amount1) = rp.positionManager().fees(rp.tokenId());
  }

  function sqrtPriceX96(RangePool rp) external view returns (uint160) {
    return Conversion.sqrtPriceX96(rp.pool());
  }

  function price(RangePool rp) external view returns (uint256) {
    return Conversion.uintPrice(rp.pool());
  }

  function oraclePrice(RangePool rp, uint32 secondsElapsed) external view returns (uint256) {
    return Conversion.oracleUintPrice(rp.pool(), secondsElapsed);
  }

  function prices(RangePool rp) external view returns (uint256 priceToken0, uint256 priceToken1) {
    priceToken1 = Conversion.uintPrice(rp.pool());
    priceToken0 = Helper.priceToken0(
      priceToken1,
      ERC20(rp.pool().token0()).decimals(),
      ERC20(rp.pool().token1()).decimals()
    );
  }

  function oraclePrices(RangePool rp, uint32 secondsElapsed)
    external
    view
    returns (uint256 priceToken0, uint256 priceToken1)
  {
    priceToken1 = Conversion.oracleUintPrice(rp.pool(), secondsElapsed);
    priceToken0 = Helper.priceToken0(
      priceToken1,
      ERC20(rp.pool().token0()).decimals(),
      ERC20(rp.pool().token1()).decimals()
    );
  }

  function tokenAmountsAtLowerLimit(RangePool rp) external view returns (uint256 amount0, uint256 amount1) {
    (uint256 lowerAmount0, ) = Helper.getAmountsAtSqrtPrice(
      Helper.positionLiquidity(rp.positionManager(), rp.tokenId()),
      TickMath.getSqrtRatioAtTick(rp.lowerTick())
    );
    (uint256 higherAmount0, ) = Helper.getAmountsAtSqrtPrice(
      Helper.positionLiquidity(rp.positionManager(), rp.tokenId()),
      TickMath.getSqrtRatioAtTick(rp.upperTick())
    );
    amount0 = lowerAmount0.sub(higherAmount0);
    amount1 = 0;
  }

  function tokenAmountsAtUpperLimit(RangePool rp) external view returns (uint256 amount0, uint256 amount1) {
    (, uint256 lowerAmount1) = Helper.getAmountsAtSqrtPrice(
      Helper.positionLiquidity(rp.positionManager(), rp.tokenId()),
      TickMath.getSqrtRatioAtTick(rp.lowerTick())
    );
    (, uint256 higherAmount1) = Helper.getAmountsAtSqrtPrice(
      Helper.positionLiquidity(rp.positionManager(), rp.tokenId()),
      TickMath.getSqrtRatioAtTick(rp.upperTick())
    );
    amount0 = 0;
    amount1 = higherAmount1.sub(lowerAmount1);
  }

  function lowerLimit(RangePool rp) public view returns (uint256) {
    return Conversion.convertTickToPriceUint(rp.lowerTick(), ERC20(rp.pool().token0()).decimals());
  }

  function upperLimit(RangePool rp) public view returns (uint256) {
    return Conversion.convertTickToPriceUint(rp.upperTick(), ERC20(rp.pool().token0()).decimals());
  }

  function averagePriceAtLowerLimit(RangePool rp) external view returns (uint256 price0) {
    price0 = Helper.priceToken0(
      averagePriceAtUpperLimit(rp),
      ERC20(rp.pool().token0()).decimals(),
      ERC20(rp.pool().token1()).decimals()
    );
  }

  function averagePriceAtUpperLimit(RangePool rp) public view returns (uint256 price1) {
    price1 = Math.sqrt(lowerLimit(rp).mul(upperLimit(rp)));
  }

  function calculateDepositRatio(
    RangePool rp,
    uint256 amount0,
    uint256 amount1
  ) external view returns (uint256 amountRatioed0, uint256 amountRatioed1) {
    (amountRatioed0, amountRatioed1) = RatioCalculator.calculateRatio(
      Conversion.sqrtPriceX96(rp.pool()),
      rp.pool().liquidity(),
      amount0,
      amount1,
      rp.lowerTick(),
      rp.upperTick(),
      ERC20(rp.pool().token0()).decimals()
    );
  }
}
