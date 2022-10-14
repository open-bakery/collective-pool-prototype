// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

import './libraries/Utils.sol';
import './libraries/PoolUtils.sol';
import './libraries/RatioCalculator.sol';

contract DepositRatioCalculator {
  using SafeMath for uint256;
  using SafeERC20 for ERC20;
  using RatioCalculator for uint160;
  using PoolUtils for IUniswapV3Pool;

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

    uint256 amount0 = amountA;
    uint256 amount1 = amountB;

    if (tokenA != token0) {
      lowerLimitInTokenB = Utils.priceToken0(lowerLimitInTokenB, ERC20(token0).decimals(), ERC20(token1).decimals());
      upperLimitInTokenB = Utils.priceToken0(upperLimitInTokenB, ERC20(token0).decimals(), ERC20(token1).decimals());
      (amount0, amount1) = (amountB, amountA);
    }

    (int24 lowerTick, int24 upperTick) = Utils.convertLimitsToTicks(
      lowerLimitInTokenB,
      upperLimitInTokenB,
      IUniswapV3Pool(pool).tickSpacing(),
      ERC20(token0).decimals()
    );

    (amount0Ratioed, amount1Ratioed) = IUniswapV3Pool(pool).sqrtPriceX96().calculateRatio(
      IUniswapV3Pool(pool).liquidity(),
      amount0,
      amount1,
      lowerTick,
      upperTick,
      ERC20(token0).decimals(),
      10_000
    );
  }
}
