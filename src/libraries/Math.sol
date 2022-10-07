// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.14;

library Math {
  function sqrt(uint256 x) internal pure returns (uint256 y) {
    uint256 z = (x + 1) / 2;
    y = x;
    while (z < y) {
      y = z;
      z = (x / z + z) / 2;
    }
  }
}
