// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;

// pragma abicoder v2;

contract CollectiveFeeCalculator {
  struct Position {
    uint128 liquidity;
    uint256 balance;
    uint256 feeDebt0;
    uint256 feeDebt1;
  }

  mapping(address => Position) public position;

  function deposit(uint256 amount) external {}
}
