// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.8.0;
pragma abicoder v2;

import '../src/utility/Utils.sol';

contract SimpleStrategiesTest is Utils {
  function setUp() public {}

  function testExample() public {
    assertTrue(true);
  }

  // function compound(uint16 slippage) internal {
  //   (uint256 ibTokenLP, , ) = _intialBalances();
  //   (uint128 addedLiquidity, uint256 amountCompounded0, uint256 amountCompounded1) = simpleStrategies.compound(
  //     rangePool,
  //     slippage
  //   );
  //
  //   logr(
  //     'compound()',
  //     ['addedLiquidity', 'amountCompounded0', 'amountCompounded1', '0', '0', '0'],
  //     [uint256(addedLiquidity), amountCompounded0, amountCompounded1, 0, 0, 0]
  //   );
  //
  //   assertTrue(ERC20(rangePool.lpToken()).balanceOf(address(this)) == ibTokenLP.add(addedLiquidity));
  // }
  //
  // function stack(address token, uint16 slippage) internal {
  //   (, uint256 ibToken0, uint256 ibToken1) = _intialBalances();
  //   uint256 initialBalance = (token == rangePool.pool().token0()) ? ibToken0 : ibToken1;
  //   uint256 amount = simpleStrategies.stack(rangePool, token, slippage);
  //
  //   logr('stack()', ['amount', '0', '0', '0', '0', '0'], [uint256(amount), 0, 0, 0, 0, 0]);
  //
  //   assertTrue(amount > 0);
  //   assertTrue(ERC20(token).balanceOf(address(this)) == initialBalance.add(amount));
  // }
}
