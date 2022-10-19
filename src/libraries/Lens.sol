// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;
import '@uniswap/v3-periphery/contracts/libraries/PositionValue.sol';

import './RatioCalculator.sol';
import './Utils.sol';
import './PoolUtils.sol';

import '../RangePool.sol';
import '../LP.sol';

library Lens {
  using SafeMath for uint256;
  using PoolUtils for IUniswapV3Pool;
  using PositionValue for INonfungiblePositionManager;

  INonfungiblePositionManager public constant NFPM =
    INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
  address public constant uniswapFactory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
  uint16 constant resolution = 10_000;

  function calculateDepositRatio(
    RangePool rp,
    uint256 amount0,
    uint256 amount1
  ) external view returns (uint256 amountRatioed0, uint256 amountRatioed1) {
    (amountRatioed0, amountRatioed1) = RatioCalculator.calculateRatio(
      sqrtPriceX96(rp),
      rp.pool().liquidity(),
      amount0,
      amount1,
      rp.lowerTick(),
      rp.upperTick(),
      ERC20(rp.token0()).decimals(),
      resolution
    );
  }

  function principal(RangePool rp) external view returns (uint256 amount0, uint256 amount1) {
    (amount0, amount1) = NFPM.principal(rp.tokenId(), rp.pool().sqrtPriceX96());
  }

  function unclaimedFees(RangePool rp) external view returns (uint256 amount0, uint256 amount1) {
    (amount0, amount1) = NFPM.fees(rp.tokenId());
  }

  function sqrtPriceX96(RangePool rp) public view returns (uint160) {
    return rp.pool().sqrtPriceX96();
  }

  function price(RangePool rp) external view returns (uint256) {
    return rp.pool().uintPrice();
  }

  function oraclePrice(RangePool rp, uint32 secondsElapsed) external view returns (uint256) {
    return rp.pool().oracleUintPrice(secondsElapsed);
  }

  function prices(RangePool rp) external view returns (uint256 priceToken0, uint256 priceToken1) {
    priceToken1 = rp.pool().uintPrice();
    priceToken0 = Utils.priceToken0(priceToken1, ERC20(rp.token0()).decimals(), ERC20(rp.token1()).decimals());
  }

  function oraclePrices(RangePool rp, uint32 secondsElapsed)
    external
    view
    returns (uint256 priceToken0, uint256 priceToken1)
  {
    priceToken1 = rp.pool().oracleUintPrice(secondsElapsed);
    priceToken0 = Utils.priceToken0(priceToken1, ERC20(rp.token0()).decimals(), ERC20(rp.token1()).decimals());
  }

  function tokenAmountsAtLowerLimit(RangePool rp) external view returns (uint256 amount0, uint256 amount1) {
    (uint256 lowerAmount0, ) = Utils.getAmounts(
      uint128(LP(rp.lpToken()).balanceOf(rp.owner())),
      TickMath.getSqrtRatioAtTick(rp.lowerTick())
    );
    (uint256 higherAmount0, ) = Utils.getAmounts(
      uint128(LP(rp.lpToken()).balanceOf(rp.owner())),
      TickMath.getSqrtRatioAtTick(rp.upperTick())
    );
    amount0 = lowerAmount0.sub(higherAmount0);
    amount1 = 0;
  }

  function tokenAmountsAtUpperLimit(RangePool rp) external view returns (uint256 amount0, uint256 amount1) {
    (, uint256 lowerAmount1) = Utils.getAmounts(
      uint128(LP(rp.lpToken()).balanceOf(rp.owner())),
      TickMath.getSqrtRatioAtTick(rp.lowerTick())
    );
    (, uint256 higherAmount1) = Utils.getAmounts(
      uint128(LP(rp.lpToken()).balanceOf(rp.owner())),
      TickMath.getSqrtRatioAtTick(rp.upperTick())
    );
    amount0 = 0;
    amount1 = higherAmount1.sub(lowerAmount1);
  }

  function lowerLimit(RangePool rp) public view returns (uint256) {
    return Utils.convertTickToPriceUint(rp.lowerTick(), ERC20(rp.token0()).decimals());
  }

  function upperLimit(RangePool rp) public view returns (uint256) {
    return Utils.convertTickToPriceUint(rp.upperTick(), ERC20(rp.token0()).decimals());
  }

  function averagePriceAtLowerLimit(RangePool rp) external view returns (uint256 price0) {
    price0 = Utils.priceToken0(
      averagePriceAtUpperLimit(rp),
      ERC20(rp.token0()).decimals(),
      ERC20(rp.token1()).decimals()
    );
  }

  function averagePriceAtUpperLimit(RangePool rp) public view returns (uint256 price1) {
    price1 = Math.sqrt(lowerLimit(rp).mul(upperLimit(rp)));
  }
}
