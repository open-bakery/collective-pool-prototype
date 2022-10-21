// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

import './libraries/Conversion.sol';
import './libraries/Helper.sol';
import './libraries/RatioCalculator.sol';

contract DepositRatioCalculator {
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

    IUniswapV3Pool pool = IUniswapV3Pool(IUniswapV3Factory(uniswapFactory).getPool(tokenA, tokenB, fee));
    (address token0, address token1) = (pool.token0(), pool.token1());

    uint256 amount0 = amountA;
    uint256 amount1 = amountB;

    if (tokenA != token0) {
      lowerLimitInTokenB = Helper.priceToken0(lowerLimitInTokenB, ERC20(token0).decimals(), ERC20(token1).decimals());
      upperLimitInTokenB = Helper.priceToken0(upperLimitInTokenB, ERC20(token0).decimals(), ERC20(token1).decimals());
      (amount0, amount1) = (amountB, amountA);
    }

    (int24 lowerTick, int24 upperTick) = Conversion.convertLimitsToTicks(
      lowerLimitInTokenB,
      upperLimitInTokenB,
      pool.tickSpacing(),
      ERC20(token0).decimals()
    );

    (amount0Ratioed, amount1Ratioed) = RatioCalculator.calculateRatio(
      Conversion.sqrtPriceX96(pool),
      pool.liquidity(),
      amount0,
      amount1,
      lowerTick,
      upperTick,
      ERC20(token0).decimals()
    );
  }
}
