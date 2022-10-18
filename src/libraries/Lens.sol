// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;

import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import '@uniswap/v3-periphery/contracts/libraries/PositionValue.sol';

import './Utils.sol';
import '../RangePool.sol';

library Lens {
  using PoolUtils for IUniswapV3Pool;
  using PositionValue for INonfungiblePositionManager;

  INonfungiblePositionManager public constant NFPM =
    INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

  function principal(RangePool rp) external view returns (uint256 amount0, uint256 amount1) {
    (amount0, amount1) = NFPM.principal(rp.tokenId(), rp.pool().sqrtPriceX96());
  }

  function unclaimedFees(RangePool rp) external view returns (uint256 amount0, uint256 amount1) {
    (amount0, amount1) = NFPM.fees(rp.tokenId());
  }

  function sqrtPriceX96(RangePool rp) external view returns (uint160) {
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
}
