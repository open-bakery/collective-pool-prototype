// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;

import 'forge-std/Test.sol';

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

import './libraries/Utils.sol';
import './libraries/RatioCalculator.sol';

contract DepositRatioCalculator is Test {
  using SafeMath for uint256;
  using SafeERC20 for ERC20;
  using RatioCalculator for uint160;

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
      lowerLimitInTokenB = Utils.priceToken0(
        lowerLimitInTokenB,
        ERC20(token0).decimals(),
        ERC20(token1).decimals()
      );
      upperLimitInTokenB = Utils.priceToken0(
        upperLimitInTokenB,
        ERC20(token0).decimals(),
        ERC20(token1).decimals()
      );
      (amount0, amount1) = (amountB, amountA);
    }

    (int24 lowerTick, int24 upperTick) = Utils.convertLimitsToTicks(
      lowerLimitInTokenB,
      upperLimitInTokenB,
      IUniswapV3Pool(pool).tickSpacing(),
      ERC20(token0).decimals()
    );

    (amount0Ratioed, amount1Ratioed) = _sqrtPriceX96(pool).calculateRatio(
      _liquidity(pool),
      amount0,
      amount1,
      lowerTick,
      upperTick,
      ERC20(token0).decimals(),
      10_000
    );

    console.log('----------------------');
    console.log('calculateDepositRatio()');
    console.log('amount0Ratioed: ', amount0Ratioed);
    console.log('amount1Ratioed: ', amount1Ratioed);
    console.log('----------------------');
  }

  function _sqrtPriceX96(address pool) internal view returns (uint160 sqrtPriceX96) {
    (sqrtPriceX96, , , , , , ) = IUniswapV3Pool(pool).slot0();
  }

  function _liquidity(address pool) internal view returns (uint128) {
    return IUniswapV3Pool(pool).liquidity();
  }
}
