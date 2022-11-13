// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;
pragma abicoder v2;

import 'forge-std/Script.sol';

import '../src/utility/DeployUtils.sol';
import '../src/RangePool.sol';

import 'forge-std/console.sol';

contract AddLiquidity is DeployUtils {
  function run() external {
    vm.startBroadcast();
    RangePool pool1 = RangePool(readAddress('pool1'));
    console.log('pool1 poool', 'what');
    console.log('pool1 poool', address(pool1.pool()));
    pool1.addLiquidity(amount(10), amount(10), maxSlippage);
    vm.stopBroadcast();
  }
}
