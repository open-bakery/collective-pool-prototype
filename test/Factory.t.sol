// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;

import '../src/utility/Utils.sol';

contract ContractTest is Utils {
  function testFactoryHasAllPropertiesWhenDeployed() public {
    address positionManager = makeAddr('positionManager');
    address router = makeAddr('router');
    address uniFactory = makeAddr('uniFactory');

    RangePoolFactory factory = new RangePoolFactory(uniFactory, router, positionManager);
    factory; // Silence Warning
  }
}
