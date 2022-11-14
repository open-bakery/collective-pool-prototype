// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;

import './LocalVars.t.sol';
import 'forge-std/Test.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '../src/Lens.sol';

contract ContractTest is Test {
  function testFactoryHasAllPropertiesWhenDeployed() public {
    address positionManager = makeAddr('positionManager');
    address router = makeAddr('router');
    address uniFactory = makeAddr('uniFactory');

    RangePoolFactory factory = new RangePoolFactory(uniFactory, router, positionManager);
  }
}
