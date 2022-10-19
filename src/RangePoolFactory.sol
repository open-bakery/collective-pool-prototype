// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;

import './RangePool.sol';

contract RangePoolFactory {
  event RangePoolDeployed(address indexed deployer, address indexed rangePool);

  bytes32 public salt;

  constructor(bytes32 _salt) {
    salt = _salt;
  }

  function deployRangePool(
    address _tokenA,
    address _tokenB,
    uint24 _fee,
    uint256 _lowerLimitInTokenB,
    uint256 _upperLimitInTokenB
  ) external returns (address) {
    RangePool rangePool = new RangePool{ salt: salt }(_tokenA, _tokenB, _fee, _lowerLimitInTokenB, _upperLimitInTokenB);

    emit RangePoolDeployed(msg.sender, address(rangePool));

    return address(rangePool);
  }
}
