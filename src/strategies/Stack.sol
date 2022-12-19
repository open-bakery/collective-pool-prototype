// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;

import '@openzeppelin/contracts/math/SafeMath.sol';

import './AStrategy.sol';

import '../libraries/Swapper.sol';
import '../libraries/Helper.sol';

contract Stack is AStrategy {
  using SafeMath for uint256;

  event Stacked(address indexed receiver, uint256 amountStacked);

  function stack(
    RangePool rangePool,
    address tokenToStack,
    uint16 slippage
  ) external onlyAllowed(rangePool) returns (uint256 amountStacked) {
    Swapper.SwapParameters memory swapParams;

    {
      swapParams.recipient = address(this);
      swapParams.tokenOut = tokenToStack;
      swapParams.slippage = slippage;
      swapParams.fee = rangePool.pool().fee();
      swapParams.oracleSeconds = rangePool.oracleSeconds();
    }

    require(
      swapParams.tokenOut == rangePool.pool().token0() || swapParams.tokenOut == rangePool.pool().token1(),
      'SimpleStrategies:Can only stack tokens belonging to the pool'
    );

    CollectReturns memory cr = _collect(rangePool);

    swapParams.tokenIn = (swapParams.tokenOut == cr.token0) ? cr.token1 : cr.token0;

    uint256 amountCollected;

    (swapParams.amountIn, amountCollected) = (swapParams.tokenIn == cr.token0)
      ? (cr.amount0, cr.amount1)
      : (cr.amount1, cr.amount0);

    uint256 amountAcquired = Helper.swap(
      Swapper.SwapParameters({
        recipient: swapParams.recipient,
        tokenIn: swapParams.tokenIn,
        tokenOut: swapParams.tokenOut,
        fee: swapParams.fee,
        amountIn: swapParams.amountIn,
        slippage: swapParams.slippage,
        oracleSeconds: swapParams.oracleSeconds
      }),
      rangePool.uniswapFactory(),
      rangePool.uniswapRouter()
    );

    amountStacked = amountAcquired.add(amountCollected);

    _safeTransferToken(msg.sender, swapParams.tokenOut, amountStacked);

    emit Stacked(msg.sender, amountStacked);
  }
}
