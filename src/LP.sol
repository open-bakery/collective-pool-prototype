// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.14;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

contract LP is ERC20, Ownable {
  constructor(uint256 id)
    ERC20(
      string(abi.encodePacked('UNI_V3_LP_', Strings.toString(id))),
      string(abi.encodePacked('LP_', Strings.toString(id)))
    )
  {}

  function mint(address account, uint256 amount) external onlyOwner {
    _mint(account, amount);
  }

  function burn(address account, uint256 amount) external onlyOwner {
    _burn(account, amount);
  }
}
