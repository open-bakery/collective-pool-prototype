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
import './RangePoolManager.sol';

contract SimpleStrategies {
  using SafeERC20 for ERC20;
  using SafeMath for uint256;

  struct FeeReturns {
    address token0;
    address token1;
    uint256 amountCollected0;
    uint256 amountCollected1;
  }

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
  event Stacked(address indexed receiver, uint256 amountStacked);

  modifier onlyAllowed(RangePool rangePool) {
    address rangePoolOwner = RangePoolManager(rangePool.owner()).rangePoolOwner(address(rangePool));

    if (rangePoolOwner != address(0)) {
      require(rangePoolOwner == msg.sender, 'SimpleStrategies: Range Pool is private');
    }
    _;
  }

  modifier onlyResgitered(RangePool rangePool) {
    RangePoolManager rangePoolManager = RangePoolManager(rangePool.owner());
    require(
      rangePoolManager.isRegistered(address(rangePool), address(this)),
      'SimpleStrategies: Strategy not attached to range pool'
    );
    _;
  }

  function compound(RangePool rangePool, uint16 slippage)
    external
    onlyAllowed(rangePool)
    returns (CompoundReturns memory returnParams)
  {
    RangePoolManager rangePoolManager = RangePoolManager(rangePool.owner());

    FeeReturns memory feeReturns = FeeReturns({
      token0: address(0),
      token1: address(0),
      amountCollected0: 0,
      amountCollected1: 0
    });

    (feeReturns.token0, feeReturns.token1, feeReturns.amountCollected0, feeReturns.amountCollected1) = rangePoolManager
      .collectFees(rangePool, msg.sender);

    _maxApprove(address(rangePoolManager), feeReturns.token0, feeReturns.amountCollected0);
    _maxApprove(address(rangePoolManager), feeReturns.token1, feeReturns.amountCollected1);

    returnParams.token0 = feeReturns.token0;
    returnParams.token1 = feeReturns.token1;

    (
      returnParams.addedLiquidity,
      returnParams.amountCompounded0,
      returnParams.amountCompounded1,
      returnParams.amountRefunded0,
      returnParams.amountRefunded1
    ) = rangePoolManager.addLiquidity(
      rangePool,
      feeReturns.amountCollected0,
      feeReturns.amountCollected1,
      slippage,
      msg.sender
    );

    _safeTransferTokens(
      msg.sender,
      feeReturns.token0,
      feeReturns.token1,
      returnParams.amountRefunded0,
      returnParams.amountRefunded1
    );

    emit Compounded(
      msg.sender,
      feeReturns.token0,
      feeReturns.token1,
      returnParams.amountCompounded0,
      returnParams.amountCompounded1,
      returnParams.addedLiquidity
    );
  }

  function stack(
    RangePool rangePool,
    address tokenToStack,
    uint16 slippage
  ) external onlyAllowed(rangePool) returns (uint256 amountStacked) {
    Swapper.SwapParameters memory swapParams;
    FeeReturns memory feeReturns;

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

    RangePoolManager rangePoolManager = RangePoolManager(rangePool.owner());

    (feeReturns.token0, feeReturns.token1, feeReturns.amountCollected0, feeReturns.amountCollected1) = rangePoolManager
      .collectFees(rangePool, msg.sender);

    swapParams.tokenIn = (swapParams.tokenOut == feeReturns.token0) ? feeReturns.token1 : feeReturns.token0;

    uint256 amountCollected;

    (swapParams.amountIn, amountCollected) = (swapParams.tokenIn == feeReturns.token0)
      ? (feeReturns.amountCollected0, feeReturns.amountCollected1)
      : (feeReturns.amountCollected1, feeReturns.amountCollected0);

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

  function _safeTransferTokens(
    address _recipient,
    address _token0,
    address _token1,
    uint256 _amount0,
    uint256 _amount1
  ) internal {
    _safeTransferToken(_recipient, _token0, _amount0);
    _safeTransferToken(_recipient, _token1, _amount1);
  }

  function _safeTransferToken(
    address _recipient,
    address _token,
    uint256 _amount
  ) internal {
    if (_amount != 0) ERC20(_token).safeTransfer(_recipient, _min(_amount, ERC20(_token).balanceOf(address(this))));
  }

  function _min(uint256 a, uint256 b) internal pure returns (uint256) {
    return a < b ? a : b;
  }

  function _maxApprove(
    address spender,
    address token,
    uint256 minimumAmount
  ) private {
    if (ERC20(token).allowance(address(this), spender) < minimumAmount) {
      ERC20(token).safeApprove(spender, type(uint256).max);
    }
  }
}
