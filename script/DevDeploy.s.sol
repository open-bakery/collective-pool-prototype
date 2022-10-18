// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

import 'forge-std/Script.sol';
import 'forge-std/console2.sol';

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import '../src/RangePool.sol';

contract Deploy is Script {
  address WETH = vm.envAddress('WETH');
  address USDC = vm.envAddress('USDC');

  uint24 FEE0_05 = 500;
  uint24 FEE0_30 = 3000;
  uint24 FEE1_00 = 10000;

  function setUp() public {}

  function usdcAmount(uint256 amount) private pure returns (uint256) {
    return amount * 10**6;
  }

  function ethAmount(uint256 amount) private pure returns (uint256) {
    return amount * 10**18;
  }

  function approvePool(address token, RangePool pool) private {
    ERC20(token).approve(address(pool), type(uint256).max);
  }

  function run() external {
    vm.startBroadcast();

    RangePool pool1 = new RangePool(WETH, USDC, FEE0_30, usdcAmount(1000), usdcAmount(2000));
    console.log('Pool1 deployed: ', address(pool1));
    RangePool pool2 = new RangePool(WETH, USDC, FEE0_30, usdcAmount(500), usdcAmount(4000));
    console.log('Pool2 deployed: ', address(pool2));

    vm.stopBroadcast();
  }
}
