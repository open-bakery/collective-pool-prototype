// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

import 'forge-std/Script.sol';
import 'forge-std/console2.sol';

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import '../src/RangePool.sol';

contract Deploy is Script {
  address ARB_WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
  address ARB_USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;

  uint24 FEE0_05 = 500;
  uint24 FEE0_30 = 3000;
  uint24 FEE1_00 = 10000;

  function setUp() public {}

  function usdcAmount(uint256 amount) private returns (uint256) {
    return amount * 10**6;
  }

  function ethAmount(uint256 amount) private returns (uint256) {
    return amount * 10**18;
  }

  function approvePool(address token, RangePool pool) private {
    ERC20(token).approve(address(pool), type(uint256).max);
  }

  function run() external {
    vm.startBroadcast();

    RangePool pool1 = new RangePool(
      ARB_WETH,
      ARB_USDC,
      FEE0_30,
      usdcAmount(1000),
      usdcAmount(2000)
    );
    console.log('Pool1 deployed: ', address(pool1));
    RangePool pool2 = new RangePool(ARB_WETH, ARB_USDC, FEE0_30, usdcAmount(500), usdcAmount(4000));
    console.log('Pool2 deployed: ', address(pool2));

    vm.stopBroadcast();
  }
}
