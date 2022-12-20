// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.8.0;
pragma abicoder v2;

import './AStrategy.t.sol';
import '../src/strategies/Stack.sol';

contract StackTest is AStrategyTest {
  Stack stack;

  function setUp() public override {
    super.setUp();
    stack = new Stack();
  }

  function testStack() public {
    RangePool rp = _createRangePoolAndAttachStrategy(true, address(stack));
    _addLiquidity(rp);
    performSwaps(tokenA, simpleAmount(100, tokenA), tokenB, fee, 10);

    address token0 = rp.pool().token0();
    address token1 = rp.pool().token1();

    (uint256 initialBalance0, ) = _tokenBalances(token0, token1);

    uint256 amountStacked = stack.stack(rp, token0, 1_00);

    (uint256 currentBalance0, ) = _tokenBalances(token0, token1);

    assertTrue(amountStacked != 0);
    assertTrue(currentBalance0 == amountStacked + initialBalance0);
    assertTrue(ERC20(rp.pool().token0()).balanceOf(address(stack)) == 0);
    assertTrue(ERC20(rp.pool().token1()).balanceOf(address(stack)) == 0);
  }
}
