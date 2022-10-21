// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

import './libraries/Swapper.sol';
import './libraries/Helper.sol';
import './RangePool.sol';

contract SimpleStrategies {
  using SafeERC20 for ERC20;
  using SafeMath for uint256;

  event Compounded(address indexed receiver, uint256 amount0, uint256 amount1, uint128 liquidity);
  event Stacked(address indexed receiver, uint256 amountStacked);

  modifier onlyOwner(RangePool rangePool) {
    require(msg.sender == rangePool.owner(), 'SimpleStrategies:OW'); //Only Owner of range pool can call this function
    _;
  }

  function compound(RangePool rangePool, uint16 slippage)
    external
    onlyOwner(rangePool)
    returns (
      uint128 addedLiquidity,
      uint256 amountCompounded0,
      uint256 amountCompounded1
    )
  {
    (uint256 amountCollected0, uint256 amountCollected1) = rangePool.collectFees();

    _maxApprove(rangePool, rangePool.pool().token0(), amountCollected0);
    _maxApprove(rangePool, rangePool.pool().token1(), amountCollected1);

    (addedLiquidity, amountCompounded0, amountCompounded1) = rangePool.addLiquidity(
      amountCollected0,
      amountCollected1,
      slippage
    );

    ERC20(rangePool.lpToken()).safeTransfer(msg.sender, addedLiquidity);

    emit Compounded(msg.sender, amountCollected0, amountCollected1, slippage);
  }

  function stack(
    RangePool rangePool,
    address tokenToStack,
    uint16 slippage
  ) external onlyOwner(rangePool) returns (uint256 amountStacked) {
    require(
      tokenToStack == rangePool.pool().token0() || tokenToStack == rangePool.pool().token1(),
      'SimpleStrategies:NA' //  Can only stack tokens belonging to the pool
    );

    (uint256 amountCollected0, uint256 amountCollected1) = rangePool.collectFees();

    address tokenIn = (tokenToStack == rangePool.pool().token0())
      ? rangePool.pool().token1()
      : rangePool.pool().token0();

    (uint256 amountIn, uint256 amountCollected) = (tokenIn == rangePool.pool().token0())
      ? (amountCollected0, amountCollected1)
      : (amountCollected1, amountCollected0);

    uint256 amountAcquired = Helper.swap(
      Swapper.SwapParameters({
        recipient: address(this),
        tokenIn: tokenIn,
        tokenOut: tokenToStack,
        fee: rangePool.pool().fee(),
        amountIn: amountIn,
        slippage: slippage,
        oracleSeconds: rangePool.oracleSeconds()
      })
    );

    amountStacked = Helper.safeBalanceTransfer(
      tokenToStack,
      address(this),
      msg.sender,
      amountAcquired.add(amountCollected)
    );

    emit Stacked(msg.sender, amountStacked);
  }

  function _maxApprove(
    RangePool rangePool,
    address token,
    uint256 minimumAmount
  ) private {
    if (ERC20(token).allowance(address(this), address(rangePool)) < minimumAmount) {
      ERC20(token).safeApprove(address(rangePool), type(uint256).max);
    }
  }
}
