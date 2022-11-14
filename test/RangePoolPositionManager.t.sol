// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.9.0;
pragma abicoder v2;

import 'forge-std/Test.sol';

import '@uniswap/v3-core/contracts/UniswapV3Factory.sol';
import '@uniswap/v3-core/contracts/UniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/UniswapV3PoolDeployer.sol';

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import '../src/RangePoolFactory.sol';
import '../src/RangePool.sol';
import '../src/logs/Logs.sol';
import './LocalVars.t.sol';
import './libraries/Utils.sol';

contract RangePoolPositionManagerTest is Test {
  function setUp() public {}

  function testAddLiquidity() public {
    assertTrue(true);
  }
}
