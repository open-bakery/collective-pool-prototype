// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract Token is ERC20 {
  constructor(
    string memory name_,
    string memory symbol_,
    uint256 supply_
  ) ERC20(name_, symbol_) {
    require(supply_ != 0, 'Token: Supply must be greater than zero');
    _mint(msg.sender, supply_);
  }
}
