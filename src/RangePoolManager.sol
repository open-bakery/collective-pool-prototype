// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;

import './RangePoolManagerBase.sol';

contract RangePoolManager is RangePoolManagerBase {
  using SafeERC20 for ERC20;

  constructor(address rangePoolFactory_) RangePoolManagerBase(rangePoolFactory_) {}

  function addLiquidity(
    RangePool rangePool,
    uint256 amount0,
    uint256 amount1,
    uint16 slippage
  )
    external
    payable
    returns (
      uint128 liquidityAdded,
      uint256 amountAdded0,
      uint256 amountAdded1,
      uint256 amountRefunded0,
      uint256 amountRefunded1
    )
  {
    (liquidityAdded, amountAdded0, amountAdded1, amountRefunded0, amountRefunded1) = addLiquidity(
      rangePool,
      amount0,
      amount1,
      slippage,
      msg.sender
    );
  }

  function removeLiquidity(
    RangePool rangePool,
    uint128 liquidityAmount,
    uint16 slippage
  ) external returns (uint256 amountRemoved0, uint256 amountRemoved1) {
    (amountRemoved0, amountRemoved1) = removeLiquidity(rangePool, liquidityAmount, slippage, msg.sender);
  }

  function collectFees(RangePool rangePool)
    external
    returns (
      address tokenCollected0,
      address tokenCollected1,
      uint256 collectedFees0,
      uint256 collectedFees1
    )
  {
    (tokenCollected0, tokenCollected1, collectedFees0, collectedFees1) = collectFees(rangePool, msg.sender);
  }

  function updateRange(
    RangePool rangePool,
    address tokenA,
    uint256 lowerLimitA,
    uint256 upperLimitA,
    uint16 slippage
  )
    external
    returns (
      uint128 liquidityAdded,
      uint256 amountAdded0,
      uint256 amountAdded1,
      uint256 amountRefunded0,
      uint256 amountRefunded1
    )
  {
    (liquidityAdded, amountAdded0, amountAdded1, amountRefunded0, amountRefunded1) = updateRange(
      rangePool,
      tokenA,
      lowerLimitA,
      upperLimitA,
      slippage,
      msg.sender
    );
  }
}
