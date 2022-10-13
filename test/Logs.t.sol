// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.9.0;
pragma abicoder v2;

import '../src/RangePool.sol';
import './LocalVars.t.sol';
import '../src/logs/Logs.sol';

contract LogsTest is Test, LocalVars, Logs {
  RangePool public rangePool;

  constructor() {
    rangePool = new RangePool(MAIN_USDC, MAIN_WETH, 500, 0.001 ether, 0.0005 ether);
  }

  function setUp() public {}

  function testLogsFull() public {
    uint256 amount0 = 20_000;
    uint256 amount1 = 5 ether;
    ERC20(rangePool.token0()).approve(address(rangePool), type(uint256).max);
    ERC20(rangePool.token1()).approve(address(rangePool), type(uint256).max);
    deal(rangePool.token0(), address(this), amount0);
    deal(rangePool.token1(), address(this), amount1);
    rangePool.addLiquidity(amount0, amount1, 1_00);

    logAveragePrices();
    logLimits();
    logTokenAmountsAtLimits();
    logPrices();
    logOraclePrices(60);
  }

  function logAveragePrices() public view {
    uint256 price0 = rangePool.averagePriceAtLowerLimit();
    uint256 price1 = rangePool.averagePriceAtUpperLimit();

    logr('logAveragePrices()', ['price0', 'price1', '0', '0', '0', '0'], [uint256(price0), price1, 0, 0, 0, 0]);
  }

  function logTokenAmountsAtLimits() public view {
    (uint256 lowerAmount0, uint256 lowerAmount1) = rangePool.tokenAmountsAtLowerLimit();
    (uint256 upperAmount0, uint256 upperAmount1) = rangePool.tokenAmountsAtUpperLimit();

    logr(
      'logTokenAmountsAtLimits()',
      ['lowerAmount0', 'lowerAmount1', 'upperAmount0', 'upperAmount1', '0', '0'],
      [uint256(lowerAmount0), lowerAmount1, upperAmount0, upperAmount1, 0, 0]
    );
  }

  function logRatios(uint256 amount0, uint256 amount1) public view {
    (uint256 amountRatioed0, uint256 amountRatioed1) = rangePool.calculateDepositRatio(amount0, amount1);

    logr(
      'logRatios()',
      ['amountRatioed0', 'amountRatioed1', '0', '0', '0', '0'],
      [uint256(amountRatioed0), amountRatioed1, 0, 0, 0, 0]
    );
  }

  function logPrices() public view {
    (uint256 price0, uint256 price1) = rangePool.prices();

    logr('logPrices()', ['price0', 'price1', '0', '0', '0', '0'], [uint256(price0), price1, 0, 0, 0, 0]);
  }

  function logOraclePrices(uint32 _seconds) public view {
    (uint256 price0, uint256 price1) = rangePool.oraclePrices(_seconds);

    logr('logOraclePrices()', ['price0', 'price1', '0', '0', '0', '0'], [uint256(price0), price1, 0, 0, 0, 0]);
  }

  function logLimits() public view {
    uint256 lowerLimit = rangePool.lowerLimit();
    uint256 upperLimit = rangePool.upperLimit();

    logr(
      'logLimits()',
      ['lowerLimit', 'upperLimit', '0', '0', '0', '0'],
      [uint256(lowerLimit), upperLimit, 0, 0, 0, 0]
    );
  }
}
