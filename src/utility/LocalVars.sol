// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.9.0;
pragma abicoder v2;

import 'forge-std/Test.sol';

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';

import '../Lens.sol';
import '../RangePoolManager.sol';
import '../RangePoolFactory.sol';
import '../RangePool.sol';
import '../SimpleStrategies.sol';
import './Token.sol';

abstract contract LocalVars is Test {
  struct PoolProps {
    address tokenA;
    address tokenB;
    uint24 fee;
  }

  struct Tokens {
    address weth;
    address dai;
    address usdc;
    //    address gmx;
  }

  IUniswapV3Factory public uniswapFactory = IUniswapV3Factory(vm.envAddress('UNISWAP_V3_FACTORY'));
  INonfungiblePositionManager public positionManager = INonfungiblePositionManager(vm.envAddress('UNISWAP_V3_NFPM'));
  ISwapRouter public uniswapRouter = ISwapRouter(vm.envAddress('UNISWAP_V3_ROUTER'));

  Tokens public tokens;
  RangePoolFactory public rangePoolFactory;
  RangePoolManager public rangePoolManager;
  RangePool public rangePool;
  SimpleStrategies public simpleStrategies;
  Lens public lens;

  address public ARB_WETH = vm.envAddress('ARB_WETH');
  address public ARB_USDC = vm.envAddress('ARB_USDC');
  address public ARB_GMX = vm.envAddress('ARB_GMX');
  address public MAIN_WETH = vm.envAddress('MAIN_WETH');
  address public MAIN_USDC = vm.envAddress('MAIN_USDC');
  address public MAIN_WBTC = vm.envAddress('MAIN_WBTC');
  address public MAIN_DAI = vm.envAddress('MAIN_DAI');
  address public MAIN_FRAX = vm.envAddress('MAIN_FRAX');
  address public MAIN_APE = vm.envAddress('MAIN_APE');
  address public WETH = vm.envAddress('WETH');
  address public USDC = vm.envAddress('USDC');
}
