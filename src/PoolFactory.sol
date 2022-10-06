// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

// import '@uniswap/v3-core/contracts/libraries/FullMath.sol';

contract PoolFactory {
  constructor() {}

  // function muldiv(
  //   uint256 a,
  //   uint256 b,
  //   uint256 c
  // ) external pure returns (uint256) {
  //   return FullMath.mulDiv(a, b, c);
  // }

  function add(uint256 a, uint256 b) external pure returns (uint256) {
    return a + b;
  }
}
