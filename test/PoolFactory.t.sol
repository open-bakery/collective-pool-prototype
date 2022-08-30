// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import 'forge-std/Test.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

contract PoolFactoryTest is Test {
  address swapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
  address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

  address uniswapFactory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

  uint24 fee = 3000;

  address recipient;
  uint256 deadline;
  uint256 amountIn;
  uint256 amountOutMinimum;
  uint160 sqrtPriceLimitX96;

  struct ExactInputSingleParams {
    address tokenIn;
    address tokenOut;
    uint24 fee;
    address recipient;
    uint256 deadline;
    uint256 amountIn;
    uint256 amountOutMinimum;
    uint160 sqrtPriceLimitX96;
  }

  function setUp() public {}

  /* function testExample() public {
    assertTrue(true);
    address daiPool = IUniswapV3Factory(uniswapFactory).getPool(weth, dai, 3000);
    (
      uint128 liquidityGross,
      int128 liquidityNet,
      uint256 feeGrowthOutside0X128,
      uint256 feeGrowthOutside1X128,
      int56 tickCumulativeOutside,
      uint160 secondsPerLiquidityOutsideX128,
      uint32 secondsOutside,
      bool initialized
    ) = IUniswapV3Pool(daiPool).ticks(-73677);
  } */
}
