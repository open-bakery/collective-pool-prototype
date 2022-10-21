// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.9.0;
pragma abicoder v2;

import '../src/RangePool.sol';
import '../src/logs/Logs.sol';
import '../src/Lens.sol';

contract LogsTest is Test, Logs {
  Lens public lens;

  constructor() {
    lens = new Lens();
  }

  function logPrincipal(RangePool rangePool) public view {
    (uint256 amount0, uint256 amount1) = lens.principal(rangePool);
    logr('logPrincipal()', ['amount0', 'amount1', '0', '0', '0', '0'], [uint256(amount0), amount1, 0, 0, 0, 0]);
  }

  function logUnclaimedFees(RangePool rangePool) public view {
    (uint256 amount0, uint256 amount1) = lens.unclaimedFees(rangePool);
    logr('logUnclaimedFees()', ['amount0', 'amount1', '0', '0', '0', '0'], [uint256(amount0), amount1, 0, 0, 0, 0]);
  }

  function logAveragePrices(RangePool rangePool) public view {
    uint256 price0 = lens.averagePriceAtLowerLimit(rangePool);
    uint256 price1 = lens.averagePriceAtUpperLimit(rangePool);

    logr('logAveragePrices()', ['price0', 'price1', '0', '0', '0', '0'], [uint256(price0), price1, 0, 0, 0, 0]);
  }

  function logTokenAmountsAtLimits(RangePool rangePool) public view {
    (uint256 lowerAmount0, uint256 lowerAmount1) = lens.tokenAmountsAtLowerLimit(rangePool);
    (uint256 upperAmount0, uint256 upperAmount1) = lens.tokenAmountsAtUpperLimit(rangePool);

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
    (uint256 amountRatioed0, uint256 amountRatioed1) = lens.calculateDepositRatio(rangePool, amount0, amount1);

    logr(
      'logRatios()',
      ['amountRatioed0', 'amountRatioed1', '0', '0', '0', '0'],
      [uint256(amountRatioed0), amountRatioed1, 0, 0, 0, 0]
    );
  }

  function logPrices(RangePool rangePool) public view {
    (uint256 price0, uint256 price1) = lens.prices(rangePool);

    logr('logPrices()', ['price0', 'price1', '0', '0', '0', '0'], [uint256(price0), price1, 0, 0, 0, 0]);
  }

  function logOraclePrices(RangePool rangePool, uint32 _seconds) public view {
    (uint256 price0, uint256 price1) = lens.oraclePrices(rangePool, _seconds);

    logr('logOraclePrices()', ['price0', 'price1', '0', '0', '0', '0'], [uint256(price0), price1, 0, 0, 0, 0]);
  }

  function logLimits(RangePool rangePool) public view {
    uint256 lowerLimit = lens.lowerLimit(rangePool);
    uint256 upperLimit = lens.upperLimit(rangePool);

    logr(
      'logLimits()',
      ['lowerLimit', 'upperLimit', '0', '0', '0', '0'],
      [uint256(lowerLimit), upperLimit, 0, 0, 0, 0]
    );
  }
}
