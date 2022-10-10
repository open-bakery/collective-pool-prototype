// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;

import 'forge-std/Test.sol';

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import '@uniswap/v3-core/contracts/libraries/FixedPoint96.sol';

import '@uniswap/v3-periphery/contracts/NonfungiblePositionManager.sol';

import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol';
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';

import '@uniswap/v3-periphery/contracts/libraries/PositionValue.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import '@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol';
import '@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol';

import './libraries/Conversions.sol';
import './libraries/Utils.sol';
import './libraries/Math.sol';

contract SDCA is Test {
  using SafeMath for uint256;
  using SafeERC20 for ERC20;

  IUniswapV3Factory public constant uniswapFactory =
    IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
  ISwapRouter public constant router = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

  uint32 public oracleSeconds = 60;
  uint16 constant resolution = 10_000;

  function swap(
    address tokenIn,
    address tokenOut,
    uint24 fee,
    uint256 amountIn,
    uint16 slippage
  ) external returns (uint256 amountOut) {
    ERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
    amountOut = _swap(tokenIn, tokenOut, fee, amountIn, slippage);
  }

  function _swap(
    address _tokenIn,
    address _tokenOut,
    uint24 _fee,
    uint256 _amountIn,
    uint16 _slippage
  ) internal returns (uint256 _amountOut) {
    IUniswapV3Pool pool = IUniswapV3Pool(uniswapFactory.getPool(_tokenIn, _tokenOut, _fee));

    ERC20(_tokenIn).safeApprove(address(router), _amountIn);

    uint256 expectedAmountOut = _tokenOut == pool.token0()
      ? _convert1ToToken0(pool, _amountIn, true)
      : _convert0ToToken1(pool, _amountIn, true);

    uint256 amountOutMinimum = _applySlippageTolerance(false, expectedAmountOut, _slippage);

    uint160 sqrtPriceLimitX96 = _tokenIn == pool.token1()
      ? uint160(_applySlippageTolerance(true, uint256(_sqrtPriceX96(pool)), _slippage))
      : uint160(_applySlippageTolerance(false, uint256(_sqrtPriceX96(pool)), _slippage));

    ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
      tokenIn: _tokenIn,
      tokenOut: _tokenOut,
      fee: _fee,
      recipient: address(this),
      deadline: block.timestamp,
      amountIn: _amountIn,
      amountOutMinimum: amountOutMinimum,
      sqrtPriceLimitX96: sqrtPriceLimitX96
    });

    _amountOut = router.exactInputSingle(params);

    console.log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
    console.log('_swap() Function Call');
    console.log('expectedAmountOut: ', expectedAmountOut);
    console.log('amountOutMinimum: ', amountOutMinimum);
    console.log('_amountOut: ', _amountOut);
    console.log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
  }

  function _sqrtPriceX96(IUniswapV3Pool pool) internal view returns (uint160 sqrtPriceX96) {
    (sqrtPriceX96, , , , , , ) = pool.slot0();
  }

  function _applySlippageTolerance(
    bool _positive,
    uint256 _amount,
    uint16 _slippage
  ) internal pure returns (uint256 _amountAccepted) {
    _amountAccepted = _positive
      ? (_amount.mul(_slippage).div(resolution)).add(_amount)
      : _amount.sub(_amount.mul(_slippage).div(resolution));
  }

  function _convert0ToToken1(
    IUniswapV3Pool pool,
    uint256 amount0,
    bool useOracle
  ) internal view returns (uint256 amount0ConvertedToToken1) {
    uint256 price = useOracle ? _oracleUintPrice(pool, oracleSeconds) : _getPrice(pool);

    amount0ConvertedToToken1 = amount0.mul(price).div(10**ERC20(pool.token0()).decimals());
  }

  function _convert1ToToken0(
    IUniswapV3Pool pool,
    uint256 amount1,
    bool useOracle
  ) internal view returns (uint256 amount1ConvertedToToken0) {
    uint256 price = useOracle ? _oracleUintPrice(pool, oracleSeconds) : _getPrice(pool);

    amount1ConvertedToToken0 = amount1.mul(10**ERC20(pool.token0()).decimals()).div(price);
  }

  function _oracleUintPrice(IUniswapV3Pool pool, uint32 _seconds) internal view returns (uint256) {
    return
      Conversions.sqrtPriceX96ToUint(
        _oracleSqrtPricex96(pool, _seconds),
        ERC20(pool.token0()).decimals()
      );
  }

  function _oracleSqrtPricex96(IUniswapV3Pool pool, uint32 _seconds)
    internal
    view
    returns (uint160)
  {
    (int24 arithmeticMeanTick, ) = OracleLibrary.consult(address(pool), _seconds);
    return TickMath.getSqrtRatioAtTick(arithmeticMeanTick);
  }

  function _getPrice(IUniswapV3Pool pool) internal view returns (uint256) {
    return Conversions.sqrtPriceX96ToUint(_sqrtPriceX96(pool), ERC20(pool.token0()).decimals());
  }
}
