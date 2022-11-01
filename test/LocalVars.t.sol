// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.9.0;
pragma abicoder v2;

import 'forge-std/Test.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';

import '../src/RangePool.sol';

contract LocalVars is Test {
  IUniswapV3Factory public factory = IUniswapV3Factory(vm.envAddress('UNISWAP_V3_FACTORY'));
  INonfungiblePositionManager public NFPM = INonfungiblePositionManager(vm.envAddress('UNISWAP_V3_NFPM'));
  ISwapRouter public router = ISwapRouter(vm.envAddress('UNISWAP_V3_ROUTER'));

  address public WETH = vm.envAddress('WETH');
  address public USDC = vm.envAddress('USDC');
}
