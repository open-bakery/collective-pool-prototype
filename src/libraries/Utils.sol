// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.14;

import '@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol';

library Utils {
  function getPoolAddress(
    address _tokenA,
    address _tokenB,
    uint24 _fee,
    address _uniswapFactory
  ) internal pure returns (address) {
    return
      PoolAddress.computeAddress(_uniswapFactory, PoolAddress.getPoolKey(_tokenA, _tokenB, _fee));
  }

  function orderTokens(address tokenA, address tokenB)
    internal
    pure
    returns (address token0, address token1)
  {
    require(tokenA != tokenB);
    (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
  }

  function orderTicks(int24 tick0, int24 tick1)
    internal
    pure
    returns (int24 tickLower, int24 tickUpper)
  {
    (tickLower, tickUpper) = tick1 < tick0 ? (tick1, tick0) : (tick0, tick1);
  }
}
