// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import './LiquidityProviderToken.sol';

contract RangePoolProxy is Ownable {
  LiquidityProviderToken public lpToken;

  constructor() {}
}
