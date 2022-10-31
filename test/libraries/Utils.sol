// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.14;
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

library Utils {
  function simpleAmount(address token, uint256 amount) external view returns (uint256) {
    return amount * (10**ERC20(token).decimals());
  }
}
