// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.8.0;
pragma abicoder v2;

import './AStrategy.t.sol';
import '../src/strategies/EthStacker.sol';

contract EthStackerTest is AStrategyTest {
  EthStacker ethStacker;

  function setUp() public override {
    super.setUp();
    ethStacker = new EthStacker(tokenA);
  }

  function testEthStack() public {
    RangePool rp = _createRangePoolAndAttachStrategy(false, address(ethStacker));
    _addLiquidity(rp);
    performSwaps(tokenA, simpleAmount(100, tokenA), tokenB, fee, 10);

    uint256 amountStacked = ethStacker.stackEth(rp, 1_00);

    assertTrue(amountStacked != 0);
    assertTrue(ERC20(tokenA).balanceOf(address(ethStacker)) == amountStacked);
  }

  function _getBalance(RangePool _rangePool, address _token) internal view returns (uint256 _balance) {
    address token0 = _rangePool.pool().token0();
    address token1 = _rangePool.pool().token1();

    _balance = (_token == token0) ? ERC20(token0).balanceOf(address(this)) : ERC20(token1).balanceOf(address(this));
  }
}
