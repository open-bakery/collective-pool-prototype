// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import './RangePoolManager.sol';
import './LiquidityProviderToken.sol';

contract CollectivePoolSimpleStrategy {
  using SafeERC20 for ERC20;
  using SafeMath for uint256;
  using SafeERC20 for LiquidityProviderToken;

  mapping(address => LiquidityProviderToken) public lp; // lp[rangePool] = LiquidityProviderToken;

  constructor() {}

  function rangePoolLP(address rangePool) public returns (address) {
    return address(lp[rangePool]);
  }

  function addLiquidity(
    RangePool rangePool,
    uint256 amount0,
    uint256 amount1,
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
    require(amount0 + amount1 != 0, 'CollectivePoolSimpleStrategy: Must add tokens');

    RangePoolManager rangePoolManager = RangePoolManager(rangePool.owner());

    if (rangePoolLP(address(rangePool)) == address(0)) {
      lp[address(rangePool)] = new LiquidityProviderToken(rangePool.tokenId());
    }

    _maxApprove(address(rangePoolManager), rangePool.pool().token0(), amount0);
    _maxApprove(address(rangePoolManager), rangePool.pool().token1(), amount1);

    ERC20(rangePool.pool().token0()).safeTransferFrom(msg.sender, address(this), amount0);
    ERC20(rangePool.pool().token1()).safeTransferFrom(msg.sender, address(this), amount1);
    (liquidityAdded, amountAdded0, amountAdded1, amountRefunded0, amountRefunded1) = rangePoolManager.addLiquidity(
      rangePool,
      amount0,
      amount1,
      slippage,
      msg.sender
    );

    lp[address(rangePool)].mint(msg.sender, liquidityAdded);

    if (amountRefunded0 + amountRefunded1 != 0) {
      _safeTransferTokens(
        msg.sender,
        rangePool.pool().token0(),
        rangePool.pool().token1(),
        amountRefunded0,
        amountRefunded1
      );
    }
  }

  //   function collectFees(RangePool rangePool) external {
  //     (tokenCollected0, tokenCollected1, collectedFees0, collectedFees1) = rangePool.collectFees();
  //     _updateAccFeePerLiquidity(rangePool, collectedFees0, collectedFees1);
  //   }
  //   function _updateAccFeePerLiquidity(
  //     RangePool rangePool,
  //     uint256 collectedFees0,
  //     uint256 collectedFees1
  //   ) internal {
  //     if (collectedFees0 + collectedFees1 != 0) {
  //       uint256 totalLiquidity = uint256(Helper.positionLiquidity(rangePool.positionManager(), rangePool.tokenId()));
  //       accFeePerLiquidity0 += (collectedFees0 * precision) / totalLiquidity;
  //       accFeePerLiquidity1 += (collectedFees1 * precision) / totalLiquidity;
  //     }
  //   }
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
      ERC20(token).approve(spender, type(uint256).max);
    }
  }
}
