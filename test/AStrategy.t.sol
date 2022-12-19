// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.8.0;
pragma abicoder v2;

import './ARangePoolManager.t.sol';

abstract contract AStrategyTest is ARangePoolManagerTest {
  function _createRangePoolAndAttachStrategy(address strategy) internal returns (RangePool _rangePool) {
    _rangePool = _createPrivateRangePool();
    rangePoolManager.attach(address(_rangePool), strategy);
    return _rangePool;
  }
}
