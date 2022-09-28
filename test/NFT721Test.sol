// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.8.0;

import 'forge-std/Test.sol';
import '../src/NFT721.sol';

contract NFT721Test is Test {
  NFT721 public nft;

  function setUp() public {
    nft = new NFT721('Super NFT', 'NFT', 'http://crazyNFT/000000000000');
  }

  function testExample() public {
    nft.freeMint();
    console.log(nft.balanceOf(address(this)));
    console.log(nft.tokenURI(1));
  }
}
