// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;

import 'forge-std/Test.sol';

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Address.sol';

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import '@uniswap/v3-core/contracts/libraries/FixedPoint96.sol';

import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol';

import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import '@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol';
import '@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol';

import './libraries/Conversions.sol';
import './libraries/Utils.sol';
import './libraries/Math.sol';

contract RatioCalculator is Test {
  using SafeMath for uint256;
  using SafeERC20 for ERC20;

  address public constant uniswapFactory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

  constructor() {}

  function calculateDepositRatio(
    address tokenA,
    address tokenB,
    uint24 fee,
    uint256 amountA,
    uint256 amountB,
    uint256 lowerLimitInTokenB,
    uint256 upperLimitInTokenB
  ) external view returns (uint256 amount0Ratioed, uint256 amount1Ratioed) {
    require(lowerLimitInTokenB != upperLimitInTokenB, 'RangePool: Limits must be within a range');

    (lowerLimitInTokenB, upperLimitInTokenB) = (lowerLimitInTokenB < upperLimitInTokenB)
      ? (lowerLimitInTokenB, upperLimitInTokenB)
      : (upperLimitInTokenB, lowerLimitInTokenB);

    if (lowerLimitInTokenB == 0) lowerLimitInTokenB = 1;

    address pool = Utils.getPoolAddress(tokenA, tokenB, fee, uniswapFactory);

    (address token0, address token1) = Utils.orderTokens(tokenA, tokenB);

    // if (tokenA != token0) {
    //   lowerLimitInTokenB = _priceToken0(lowerLimitInTokenB);
    //   upperLimitInTokenB = _priceToken0(upperLimitInTokenB);
    // }

    // tickSpacing = IUniswapV3Pool(pool).tickSpacing();
    //
    // (lowerTick, upperTick) = Utils.convertLimitsToTicks(
    //   lowerLimitInTokenB,
    //   upperLimitInTokenB,
    //   tickSpacing,
    //   ERC20(token0).decimals()
    // );
    //
    // (amount0Ratioed, amount1Ratioed) = _calculateRatio(
    //   amount0,
    //   amount1,
    //   _lowerLimit(),
    //   _upperLimit()
    // );
  }
}
