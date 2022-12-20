// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.8.0;
pragma abicoder v2;

import './ARangePoolManager.t.sol';

abstract contract AStrategyTest is ARangePoolManagerTest {
  function _createRangePoolAndAttachStrategy(bool isPrivate, address strategy) internal returns (RangePool _rangePool) {
    if (isPrivate) {
      _rangePool = _createPrivateRangePool();
      rangePoolManager.attach(address(_rangePool), strategy);
    } else {
      _rangePool = _createCollectiveRangePool(strategy);
    }

    return _rangePool;
  }
}
