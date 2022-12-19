// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import '../RangePool.sol';
import '../RangePoolManager.sol';

abstract contract AStrategy {
  using SafeERC20 for ERC20;

  struct CollectReturns {
    address token0;
    address token1;
    uint256 amount0;
    uint256 amount1;
  }

  modifier onlyAllowed(RangePool rangePool) {
    address rangePoolOwner = RangePoolManager(rangePool.owner()).rangePoolOwner(address(rangePool));

    if (rangePoolOwner != address(0)) {
      require(rangePoolOwner == msg.sender, 'AStrategy: Range Pool is private');
    }
    _;
  }

  function _collect(RangePool _rangePool) internal returns (CollectReturns memory cr) {
    RangePoolManager rpm = RangePoolManager(_rangePool.owner());
    (cr.token0, cr.token1, cr.amount0, cr.amount1) = rpm.collectFees(_rangePool, msg.sender);
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
  ) internal {
    if (ERC20(token).allowance(address(this), spender) < minimumAmount) {
      ERC20(token).approve(spender, type(uint256).max);
    }
  }
}
