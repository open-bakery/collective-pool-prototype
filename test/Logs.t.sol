// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.8.0;
pragma abicoder v2;

import './Unit.t.sol';

contract LogsTest is Test, UnitTest {
  function fullLogs(
    address tokenA,
    uint256 amountA,
    address tokenB,
    uint256 amountB,
    uint24 fee
  ) public {}

  function logAveragePrices(RangePool rangePool) public view {
    uint256 price0 = rangePool.averagePriceAtLowerLimit();
    uint256 price1 = rangePool.averagePriceAtUpperLimit();

    logr(
      'logAveragePrices()',
      ['price0', 'price1', '0', '0', '0', '0'],
      [uint256(price0), price1, 0, 0, 0, 0]
    );
  }

  function logTokenAmountsAtLimits(RangePool rangePool) public view {
    (uint256 lowerAmount0, uint256 lowerAmount1) = rangePool.tokenAmountsAtLowerLimit();
    (uint256 upperAmount0, uint256 upperAmount1) = rangePool.tokenAmountsAtUpperLimit();

    logr(
      'logTokenAmountsAtLimits()',
      ['lowerAmount0', 'lowerAmount1', 'upperAmount0', 'upperAmount1', '0', '0'],
      [uint256(lowerAmount0), lowerAmount1, upperAmount0, upperAmount1, 0, 0]
    );
  }

  function logRatios(
    RangePool rangePool,
    uint256 amount0,
    uint256 amount1
  ) public view {
    (uint256 amountRatioed0, uint256 amountRatioed1) = rangePool.calculateDepositRatio(
      amount0,
      amount1
    );

    logr(
      'logRatios()',
      ['amountRatioed0', 'amountRatioed1', '0', '0', '0', '0'],
      [uint256(amountRatioed0), amountRatioed1, 0, 0, 0, 0]
    );
  }

  function logPrices(RangePool rangePool) public view {
    (uint256 price0, uint256 price1) = rangePool.prices();

    logr(
      'logPrices()',
      ['price0', 'price1', '0', '0', '0', '0'],
      [uint256(price0), price1, 0, 0, 0, 0]
    );
  }

  function logOraclePrices(RangePool rangePool, uint32 _seconds) public view {
    (uint256 price0, uint256 price1) = rangePool.oraclePrices(_seconds);

    logr(
      'logOraclePrices()',
      ['price0', 'price1', '0', '0', '0', '0'],
      [uint256(price0), price1, 0, 0, 0, 0]
    );
  }

  function logLimits(RangePool rangePool) public view {
    uint256 lowerLimit = rangePool.lowerLimit();
    uint256 upperLimit = rangePool.upperLimit();

    logr(
      'logLimits()',
      ['lowerLimit', 'upperLimit', '0', '0', '0', '0'],
      [uint256(lowerLimit), upperLimit, 0, 0, 0, 0]
    );
  }
}
