// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;

import './LocalVars.t.sol';
import '../src/DepositRatioCalculator.sol';
import '../src/logs/Logs.sol';
import 'forge-std/Test.sol';

contract ContractTest is Test, Logs, LocalVars {
  DepositRatioCalculator drc = new DepositRatioCalculator();

  function setUp() public {}

  function testDepositRatioCalculator() public {
    uint256 amountA = 0.2178 ether;
    uint256 amountB = 57_800000;

    (uint256 amount0Ratioed, uint256 amount1Ratioed) = drc.calculateDepositRatio(
      MAIN_WETH,
      MAIN_USDC,
      500,
      amountA,
      amountB,
      1220_000000,
      1419_000000
    );

    logr(
      'testDepositRatioCalculator()',
      ['amount0Ratioed', 'amount1Ratioed', '0', '0', '0', '0'],
      [uint256(amount0Ratioed), amount1Ratioed, 0, 0, 0, 0]
    );
  }
}
