// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;

import '../src/utility/TestHelpers.sol';
import '../src/DepositRatioCalculator.sol';

contract DepositRatioCalculatorTest is TestHelpers {
  address wallet = vm.envAddress('WALLET');
  uint256 balanceETH;
  uint256 balanceUSDC;

  DepositRatioCalculator drc = new DepositRatioCalculator();

  function setUp() public {
    balanceETH = 0 ether; // ERC20(WETH).balanceOf(wallet);
    balanceUSDC = 14_600_000000; // ERC20(USDC).balanceOf(wallet);
  }

  function testDepositRatioCalculator() public view {
    uint256 amountA = balanceETH;
    uint256 amountB = balanceUSDC;

    (uint256 amount0Ratioed, uint256 amount1Ratioed) = drc.calculateDepositRatio(
      WETH,
      USDC,
      500,
      amountA,
      amountB,
      1069_600000,
      1480_400000
    );

    logr(
      'testDepositRatioCalculator()',
      ['amount0Ratioed', 'amount1Ratioed', '0', '0', '0', '0'],
      [uint256(amount0Ratioed), amount1Ratioed, 0, 0, 0, 0]
    );
  }
}
