// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import './LocalVars.t.sol';
import '../src/DepositRatioCalculator.sol';
import '../src/logs/Logs.sol';
import 'forge-std/Test.sol';

contract ContractTest is Test, Logs, LocalVars {
  address wallet = vm.envAddress('WALLET');
  uint256 balanceETH;
  uint256 balanceUSDC;

  DepositRatioCalculator drc = new DepositRatioCalculator();

  function setUp() public {
    balanceETH = 100 ether; // ERC20(WETH).balanceOf(wallet);
    balanceUSDC = 10_000_000000; // ERC20(USDC).balanceOf(wallet);
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
      1235_300000,
      1976_400000
    );

    logr(
      'testDepositRatioCalculator()',
      ['amount0Ratioed', 'amount1Ratioed', '0', '0', '0', '0'],
      [uint256(amount0Ratioed), amount1Ratioed, 0, 0, 0, 0]
    );
  }
}
