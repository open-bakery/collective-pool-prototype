// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;

import '../src/libraries/Helper.sol';
import './ARangePool.t.sol';

contract FactoryTest is ARangePoolTest {
  function setUp() public override {
    super.setUp();
  }

  function testFactoryDeployment() public {
    RangePool rp = _deploy();

    (address token0, address token1) = _orderTokens();

    (int24 lowerTick, int24 upperTick) = Helper.validateAndConvertLimits(rp.pool(), tokenB, lowerLimitB, upperLimitB);

    assertTrue(rp.pool().token0() == token0, 'Token0 check');
    assertTrue(rp.pool().token1() == token1, 'Token1 check');
    assertTrue(rp.pool().fee() == fee, 'Fee check');
    assertTrue(rp.oracleSeconds() == oracleSeconds, 'Oracle seconds check');
    assertTrue(rp.lowerTick() == lowerTick, 'Lower Tick check');
    assertTrue(rp.upperTick() == upperTick, 'Upper Tick check');
    assertTrue(rp.owner() == address(this), 'Ownership transfer check');
  }

  function _deploy() internal returns (RangePool rangePool) {
    rangePool = RangePool(
      rangePoolFactory.deployRangePool(tokenA, tokenB, fee, oracleSeconds, lowerLimitB, upperLimitB)
    );
  }

  function _orderTokens() internal view returns (address token0, address token1) {
    (token0, token1) = (tokenA < tokenB) ? (tokenA, tokenB) : (tokenB, tokenA);
  }
}
