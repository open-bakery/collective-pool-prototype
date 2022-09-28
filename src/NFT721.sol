// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.14;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';

contract NFT721 is ERC721 {
  constructor(
    string memory name_,
    string memory symbol_,
    string memory baseURI_
  ) ERC721(name_, symbol_) {
    _setBaseURI(baseURI_);
  }

  function freeMint() external returns (bool) {
    _mint(msg.sender, totalSupply() + 1);
  }
}
