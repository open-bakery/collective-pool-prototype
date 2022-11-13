// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.14;
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';

import './Conversion.sol';
import './Helper.sol';

library Swapper {
  using SafeERC20 for ERC20;

  struct SwapParameters {
    address recipient;
    address tokenIn;
    address tokenOut;
    uint24 fee;
    uint256 amountIn;
    uint16 slippage;
    uint32 oracleSeconds;
  }

  function swap(
    SwapParameters memory params,
    address uniswapFactory,
    address router
  ) internal returns (uint256 amountOut) {
    IUniswapV3Pool swapPool = IUniswapV3Pool(
      IUniswapV3Factory(uniswapFactory).getPool(params.tokenIn, params.tokenOut, params.fee)
    );

    ERC20(params.tokenIn).safeApprove(router, params.amountIn);

    uint256 expectedAmountOut = params.tokenOut == swapPool.token0()
      ? Conversion.convert1ToToken0(
        Conversion.oracleSqrtPricex96(swapPool, params.oracleSeconds),
        params.amountIn,
        ERC20(swapPool.token0()).decimals()
      )
      : Conversion.convert0ToToken1(
        Conversion.oracleSqrtPricex96(swapPool, params.oracleSeconds),
        params.amountIn,
        ERC20(swapPool.token0()).decimals()
      );

    uint256 amountOutMinimum = Helper.applySlippageTolerance(false, expectedAmountOut, params.slippage);

    uint160 sqrtPriceLimitX96 = params.tokenIn == swapPool.token1()
      ? uint160(Helper.applySlippageTolerance(true, uint256(Conversion.sqrtPriceX96(swapPool)), params.slippage))
      : uint160(Helper.applySlippageTolerance(false, uint256(Conversion.sqrtPriceX96(swapPool)), params.slippage));

    amountOut = ISwapRouter(router).exactInputSingle(
      ISwapRouter.ExactInputSingleParams({
        tokenIn: params.tokenIn,
        tokenOut: params.tokenOut,
        fee: params.fee,
        recipient: params.recipient,
        deadline: block.timestamp,
        amountIn: params.amountIn,
        amountOutMinimum: amountOutMinimum,
        sqrtPriceLimitX96: sqrtPriceLimitX96
      })
    );
  }
}
