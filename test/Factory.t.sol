// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;

import '../src/utility/TestHelpers.sol';

contract FactoryTest is TestHelpers {
  function testFactoryHasAllPropertiesWhenDeployed() public {
    address positionManager = makeAddr('positionManager');
    address router = makeAddr('router');
    address uniFactory = makeAddr('uniFactory');

    RangePoolFactory factory = new RangePoolFactory(uniFactory, router, positionManager);
    factory; // Silence Warning
  }
}
