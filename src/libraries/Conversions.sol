// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.14;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@uniswap/v3-core/contracts/libraries/FullMath.sol';
import './Math.sol';

library Conversions {
  using SafeMath for uint256;

  // Uniswap's default is price=y/x, this means that the sqrtPriceX96 from a pool contract
  // will always be of the price of token1 relative to token0.
  function sqrtPriceX96ToUint(uint160 sqrtPriceX96, uint8 decimalsToken0)
    internal
    pure
    returns (uint256)
  {
    uint256 numerator1 = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);
    uint256 numerator2 = 10**decimalsToken0;
    return FullMath.mulDiv(numerator1, numerator2, 1 << 192);
  }

  // Uniswap's default is price=y/x, this means that the price one gets is always the amount of token1 relative to token 0.
  function uintToSqrtPriceX96(uint256 priceToken1, uint8 decimalsToken0)
    internal
    pure
    returns (uint160)
  {
    uint256 ratioX192 = FullMath.mulDiv(priceToken1, 1 << 192, 10**decimalsToken0);
    return uint160(Math.sqrt(ratioX192));
  }
}
