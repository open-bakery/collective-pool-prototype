// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;

import './AStrategy.sol';

contract Compound is AStrategy {
  struct CompoundReturns {
    address token0;
    address token1;
    uint128 addedLiquidity;
    uint256 amountCompounded0;
    uint256 amountCompounded1;
    uint256 amountRefunded0;
    uint256 amountRefunded1;
  }

  event Compounded(
    address indexed receiver,
    address indexed token0,
    address indexed token1,
    uint256 amount0,
    uint256 amount1,
    uint128 liquidity
  );

  function compound(RangePool rangePool, uint16 slippage)
    external
    onlyAllowed(rangePool)
    returns (CompoundReturns memory returnParams)
  {
    RangePoolManager rangePoolManager = RangePoolManager(rangePool.owner());

    CollectReturns memory cr = _collect(rangePool);

    _maxApprove(address(rangePoolManager), cr.token0, cr.amount0);
    _maxApprove(address(rangePoolManager), cr.token1, cr.amount1);

    returnParams.token0 = cr.token0;
    returnParams.token1 = cr.token1;

    (
      returnParams.addedLiquidity,
      returnParams.amountCompounded0,
      returnParams.amountCompounded1,
      returnParams.amountRefunded0,
      returnParams.amountRefunded1
    ) = rangePoolManager.addLiquidity(rangePool, cr.amount0, cr.amount1, slippage, msg.sender);

    _safeTransferTokens(msg.sender, cr.token0, cr.token1, returnParams.amountRefunded0, returnParams.amountRefunded1);

    emit Compounded(
      msg.sender,
      cr.token0,
      cr.token1,
      returnParams.amountCompounded0,
      returnParams.amountCompounded1,
      returnParams.addedLiquidity
    );
  }
}
