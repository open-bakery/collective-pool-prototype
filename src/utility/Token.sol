// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract Token is ERC20 {
  mapping(address => uint256) public ethBalanceOf;

  constructor(
    string memory name_,
    string memory symbol_,
    uint8 decimals_,
    uint256 supply_
  ) ERC20(name_, symbol_) {
    _setupDecimals(decimals_);
    _mint(msg.sender, supply_);
  }

  function deposit() external payable {
    _mint(msg.sender, msg.value);
    ethBalanceOf[msg.sender] += msg.value;
  }

  function withdraw(uint256 wad) public {
    require(ethBalanceOf[msg.sender] >= wad);
    ethBalanceOf[msg.sender] -= wad;
    msg.sender.transfer(wad);
  }
}
