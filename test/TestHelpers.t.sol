// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.9.0;
pragma abicoder v2;

import '../src/utility/TestHelpers.sol';

contract TestHelpersTest is TestHelpers {
  function setUp() public {}

  function testCloseTo() public {
    assertTrue(isCloseTo(10, 12, 2));
    assertTrue(isCloseTo(10, 8, 2));
    assertTrue(!isCloseTo(10, 7, 2));
    assertTrue(!isCloseTo(10, 13, 2));
  }

  function testSol() public view {
    console.log(address(0xfade));
  }
}
