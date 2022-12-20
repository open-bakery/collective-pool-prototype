// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.9.0;
pragma abicoder v2;

import './ARangePool.t.sol';

abstract contract ARangePoolManagerTest is ARangePoolTest {
  function setUp() public virtual override {
    super.setUp();
    rangePoolManager = new RangePoolManager(address(rangePoolFactory), address(0));
  }

  function _addLiquidity(RangePool _rangePool)
    internal
    returns (
      uint128 _liquidityAdded,
      uint256 _amountAdded0,
      uint256 _amountAdded1,
      uint256 _amountRefunded0,
      uint256 _amountRefunded1
    )
  {
    uint256 _amount0 = 10_000 ether; // DAI
    uint256 _amount1 = 10 ether; // WETH
    uint16 _slippage = 1_00;

    _approveAndDeal(tokenB, tokenA, _amount0, _amount1, address(rangePoolManager), address(this));

    (_liquidityAdded, _amountAdded0, _amountAdded1, _amountRefunded0, _amountRefunded1) = rangePoolManager.addLiquidity(
      _rangePool,
      _amount0,
      _amount1,
      _slippage
    );
  }

  function _createCollectiveRangePool(address strategy) internal returns (RangePool _rangePool) {
    _rangePool = RangePool(
      rangePoolManager.createCollectiveRangePool(tokenA, tokenB, fee, oracleSeconds, lowerLimitB, upperLimitB, strategy)
    );
  }

  function _createPrivateRangePool() internal returns (RangePool _rangePool) {
    _rangePool = RangePool(
      rangePoolManager.createPrivateRangePool(tokenA, tokenB, fee, oracleSeconds, lowerLimitB, upperLimitB)
    );
  }
}
