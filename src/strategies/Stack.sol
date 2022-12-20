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
    amountStacked = _stack(rangePool, tokenToStack, slippage);
    _safeTransferToken(msg.sender, tokenToStack, amountStacked);
    emit Stacked(msg.sender, amountStacked);
  }

  function _stack(
    RangePool _rangePool,
    address _tokenToStack,
    uint16 _slippage
  ) internal returns (uint256 _amountStacked) {
    Swapper.SwapParameters memory swapParams;

    {
      swapParams.recipient = address(this);
      swapParams.tokenOut = _tokenToStack;
      swapParams.slippage = _slippage;
      swapParams.fee = _rangePool.pool().fee();
      swapParams.oracleSeconds = _rangePool.oracleSeconds();
    }

    require(
      swapParams.tokenOut == _rangePool.pool().token0() || swapParams.tokenOut == _rangePool.pool().token1(),
      'SimpleStrategies:Can only stack tokens belonging to the pool'
    );

    CollectReturns memory cr = _collect(_rangePool);

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
      _rangePool.uniswapFactory(),
      _rangePool.uniswapRouter()
    );

    _amountStacked = amountAcquired.add(amountCollected);
  }
}
