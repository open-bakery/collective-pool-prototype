// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.14;
pragma abicoder v2;

import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import './Utils.sol';
import './RatioCalculator.sol';
import './PoolUtils.sol';

library Swapper {
  using RatioCalculator for uint160;
  using PoolUtils for IUniswapV3Pool;
  using SafeMath for uint256;
  using SafeERC20 for ERC20;

  address constant uniswapFactory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
  address constant router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

  function swap(
    address recipient,
    address tokenIn,
    address tokenOut,
    uint24 fee,
    uint256 amountIn,
    uint16 slippage,
    uint32 oracleSeconds,
    uint16 resolution
  ) external returns (uint256 amountOut) {
    IUniswapV3Pool swapPool = IUniswapV3Pool(Utils.getPoolAddress(tokenIn, tokenOut, fee, uniswapFactory));

    ERC20(tokenIn).safeApprove(router, amountIn);

    uint256 expectedAmountOut = tokenOut == swapPool.token0()
      ? swapPool.oracleSqrtPricex96(oracleSeconds).convert1ToToken0(amountIn, ERC20(swapPool.token0()).decimals())
      : swapPool.oracleSqrtPricex96(oracleSeconds).convert0ToToken1(amountIn, ERC20(swapPool.token0()).decimals());

    uint256 amountOutMinimum = Utils.applySlippageTolerance(false, expectedAmountOut, slippage, resolution);

    uint160 sqrtPriceLimitX96 = tokenIn == swapPool.token1()
      ? uint160(Utils.applySlippageTolerance(true, uint256(swapPool.sqrtPriceX96()), slippage, resolution))
      : uint160(Utils.applySlippageTolerance(false, uint256(swapPool.sqrtPriceX96()), slippage, resolution));

    ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
      tokenIn: tokenIn,
      tokenOut: tokenOut,
      fee: fee,
      recipient: recipient,
      deadline: block.timestamp,
      amountIn: amountIn,
      amountOutMinimum: amountOutMinimum,
      sqrtPriceLimitX96: sqrtPriceLimitX96
    });

    amountOut = ISwapRouter(router).exactInputSingle(params);
  }
}
