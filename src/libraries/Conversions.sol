// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.14;

library Conversions {
  // Uniswap's default is price=y/x, this means that the sqrtPriceX96 from a pool contract
  // will always be of the price of token1 relative to token0.
  function sqrtPriceX96ToUint(uint160 sqrtPriceX96, uint8 decimalsToken0)
    internal
    pure
    returns (uint256)
  {
    uint256 a = uint256(sqrtPriceX96) * uint256(sqrtPriceX96) * 10**decimalsToken0;
    uint256 b = (96 * 2);
    return a >> b;
  }

  // Uniswap's default is price=y/x, this means that the price one gets is always the amount of token1 relative to token 0.
  function uintToSqrtPriceX96(uint256 priceToken1, uint8 decimalsToken0)
    internal
    pure
    returns (uint160)
  {
    uint256 ratioX192 = (priceToken1 << 192) / 10**decimalsToken0;
    return uint160(_sqrt(ratioX192));
  }

  function _sqrt(uint256 x) internal pure returns (uint256 y) {
    uint256 z = (x + 1) / 2;
    y = x;
    while (z < y) {
      y = z;
      z = (x / z + z) / 2;
    }
  }
}