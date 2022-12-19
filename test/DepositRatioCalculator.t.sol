// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;

import '../src/utility/TestHelpers.sol';
import '../src/DepositRatioCalculator.sol';

contract DepositRatioCalculatorTest is TestHelpers {
  address wallet = vm.envAddress('WALLET');

  DepositRatioCalculator drc = new DepositRatioCalculator();

  function testDepositRatioCalculator() public view {
    address token0 = ARB_WETH;
    address token1 = ARB_GMX;
    uint24 fee = 3000;
    uint256 amount0 = 44 ether;
    uint256 amount1 = 0;
    uint256 lowerLimitToken1 = 2.5042 ether;
    uint256 upperLimitToken1 = 83.244 ether;

    (uint256 amount0Ratioed, uint256 amount1Ratioed) = drc.calculateDepositRatio(
      token0,
      token1,
      fee,
      amount0,
      amount1,
      lowerLimitToken1,
      upperLimitToken1
    );

    logr(
      'testDepositRatioCalculator()',
      ['amount0Ratioed', 'amount1Ratioed', '0', '0', '0', '0'],
      [uint256(amount0Ratioed), amount1Ratioed, 0, 0, 0, 0]
    );
  }
}
