// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.8.0;
pragma abicoder v2;

import 'forge-std/Test.sol';
import '../src/RangePool.sol';

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

contract PoolTest is Test {
  address public USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
  address public WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
  address public factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
  address public NFPM = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;

  uint24 public fee = 500;

  RangePool public automatedPool;

  function setUp() public {}

  function testExample() public {}
}
