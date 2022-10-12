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

    if (tokenA != token0) {
      lowerLimitInTokenB = _priceToken0(lowerLimitInTokenB);
      upperLimitInTokenB = _priceToken0(upperLimitInTokenB);
    }

    tickSpacing = IUniswapV3Pool(pool).tickSpacing();

    (int24 lowerTick, int24 upperTick) = Utils.convertLimitsToTicks(
      lowerLimitInTokenB,
      upperLimitInTokenB,
      tickSpacing,
      ERC20(token0).decimals()
    );

    uint8 decimalsToken0 = ERC20(token0).decimals();
    uint8 decimalsToken1 = ERC20(token1).decimals();

    (amount0Ratioed, amount1Ratioed) = _calculateRatio(
      amount0,
      amount1,
      Utils.convertTickToUint(lowerTick, decimalsToken0),
      Utils.convertTickToUint(upperTick, decimalsToken0),
      decimalsToken0,
      decimalsToken1
    );
  }

  function _calculateRatio(
    uint256 _amount0,
    uint256 _amount1,
    uint256 _lowerLimit,
    uint256 _upperLimit,
    uint8 _decimalsToken0,
    uint8 _decimalsToken1
  ) internal view returns (uint256 amount0Ratioed, uint256 amount1Ratioed) {
    uint256 sumConvertedToToken1 = _convert0ToToken1(_amount0, _decimalsToken0).add(_amount1);
    (uint256 amount0ConvertedToToken1, uint256 amount1) = _applyRatio(
      sumConvertedToToken1,
      _lowerLimit,
      _upperLimit,
      _decimalsToken0
    );
    amount0Ratioed = _convert1ToToken0(amount0ConvertedToToken1);
    amount1Ratioed = amount1;
  }

  function _applyRatio(
    uint256 _amountSumInToken1,
    uint256 _lowerLimit,
    uint256 _upperLimit,
    uint8 _decimalsToken0
  ) internal view returns (uint256 _ratio0InToken1, uint256 _ratio1) {
    uint16 precision = 10_000;
    (uint256 ratio0, uint256 ratio1) = _getRatioForLiquidity(
      _lowerLimit,
      _upperLimit,
      precision,
      _decimalsToken0
    );
    _ratio0InToken1 = _amountSumInToken1.mul(ratio0).div(precision);
    _ratio1 = _amountSumInToken1.mul(ratio1).div(precision);
  }

  function _getRatioForLiquidity(
    uint256 _lowerLimit,
    uint256 _upperLimit,
    uint16 _precision,
    uint8 _decimalsToken0
  ) internal view returns (uint256 _ratioToken0, uint256 _ratioToken1) {
    (uint256 amount0, uint256 amount1) = _getAmountsFromLiquidity(
      _lowerLimit,
      _upperLimit,
      _decimalsToken0
    );
    uint256 amount0ConvertedToToken1 = _convert0ToToken1(amount0, _decimalsToken0);
    uint256 sum = amount0ConvertedToToken1.add(amount1);
    if (sum == 0) sum = 1;
    _ratioToken0 = amount0ConvertedToToken1.mul(_precision).div(sum);
    _ratioToken1 = amount1.mul(_precision).div(sum);
  }

  function _getAmountsFromLiquidity(
    uint256 _lowerLimit,
    uint256 _upperLimit,
    uint8 _decimalsToken0
  ) internal view returns (uint256 _amount0, uint256 _amount1) {
    // Convert the manual entered range to ticks and then to sqrtPriceX96 in order to
    // utilize the available price range relative to tick spacing.
    (int24 lowerTick, int24 upperTick) = Utils.convertLimitsToTicks(
      _lowerLimit,
      _upperLimit,
      tickSpacing,
      ERC20(token0).decimals()
    );

    uint160 lowerLimitSqrtPricex96 = TickMath.getSqrtRatioAtTick(lowerTick);
    uint160 upperLimitSqrtPricex96 = TickMath.getSqrtRatioAtTick(upperTick);

    (_amount0, _amount1) = LiquidityAmounts.getAmountsForLiquidity(
      _sqrtPriceX96(),
      lowerLimitSqrtPricex96,
      upperLimitSqrtPricex96,
      _liquidity()
    );
  }

  function _convert0ToToken1(uint256 amount0, uint8 _decimalsToken0)
    internal
    view
    returns (uint256 amount0ConvertedToToken1)
  {
    uint256 price = _uintPrice(_decimalsToken0);

    amount0ConvertedToToken1 = amount0.mul(price).div(10**_decimalsToken0);
  }

  function _priceToken0(uint256 _priceToken1) internal view returns (uint256) {
    uint8 decimalsToken0 = ERC20(token0).decimals();
    uint8 decimalsToken1 = ERC20(token1).decimals();
    if (_priceToken1 == 0) _priceToken1 = 1;
    return (10**(SafeMath.add(decimalsToken0, decimalsToken1))).div(_priceToken1);
  }

  function _uintPrice(uint8 _decimalsToken0) internal view returns (uint256) {
    return Conversions.sqrtPriceX96ToUint(_sqrtPriceX96(), _decimalsToken0);
  }

  function _sqrtPriceX96() internal view returns (uint160 sqrtPriceX96) {
    (sqrtPriceX96, , , , , , ) = IUniswapV3Pool(pool).slot0();
  }
}
