// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.14;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/libraries/FixedPoint96.sol';
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';

import '@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol';
import '@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol';

import './Conversions.sol';

library PoolUtils {
  using SafeMath for uint256;

  function sqrtPriceX96(IUniswapV3Pool pool) public view returns (uint160 sqrtPriceX96) {
    (sqrtPriceX96, , , , , , ) = pool.slot0();
  }

  function oracleSqrtPricex96(IUniswapV3Pool pool, uint32 elapsedSeconds) public view returns (uint160) {
    (int24 arithmeticMeanTick, ) = OracleLibrary.consult(address(pool), elapsedSeconds);
    return TickMath.getSqrtRatioAtTick(arithmeticMeanTick);
  }

  function uintPrice(IUniswapV3Pool pool) external view returns (uint256) {
    return Conversions.sqrtPriceX96ToUint(sqrtPriceX96(pool), ERC20(pool.token0()).decimals());
  }

  function oracleUintPrice(IUniswapV3Pool pool, uint32 elapsedSeconds) external view returns (uint256) {
    return Conversions.sqrtPriceX96ToUint(oracleSqrtPricex96(pool, elapsedSeconds), ERC20(pool.token0()).decimals());
  }
}
