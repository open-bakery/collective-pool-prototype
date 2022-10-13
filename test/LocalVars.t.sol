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

  address public ARB_WETH = vm.envAddress('ARB_WETH');
  address public ARB_USDC = vm.envAddress('ARB_USDC');
  address public ARB_GMX = vm.envAddress('ARB_GMX');
  address public MAIN_WETH = vm.envAddress('MAIN_WETH');
  address public MAIN_USDC = vm.envAddress('MAIN_USDC');
  address public MAIN_WBTC = vm.envAddress('MAIN_WBTC');
  address public MAIN_DAI = vm.envAddress('MAIN_DAI');
  address public MAIN_FRAX = vm.envAddress('MAIN_FRAX');
  address public MAIN_APE = vm.envAddress('MAIN_APE');
}
