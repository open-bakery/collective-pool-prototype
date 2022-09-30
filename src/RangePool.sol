// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.14;
pragma abicoder v2;

import 'forge-std/Test.sol';

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';

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

// All prices and ranges in Uniswap are denominated in token1 (y) relative to token0 (x): (y/x as in x*y=k)
//Contract responsible for creating new pools.
contract RangePool is IERC721Receiver, Test {
  using PositionValue for NonfungiblePositionManager;
  using TransferHelper for address;

  address public constant uniswapFactory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
  ISwapRouter public constant router = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
  NonfungiblePositionManager public constant NFPM =
    NonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

  address public token0;
  address public token1;
  address public pool;
  uint24 public fee;
  int24 public lowerTick;
  int24 public upperTick;
  int24 public tickSpacing;
  uint256 public tokenId;
  bool locked;

  struct Deposit {
    address owner;
    uint128 liquidity;
    address token0;
    address token1;
  }

  mapping(uint256 => Deposit) public deposits;

  constructor(
    address _tokenA,
    address _tokenB,
    uint24 _fee,
    uint256 _lowerLimit,
    uint256 _upperLimit
  ) {
    address _poolAddress = Utils.getPoolAddress(_tokenA, _tokenB, _fee, uniswapFactory);

    pool = _poolAddress;
    (token0, token1) = Utils.orderTokens(_tokenA, _tokenB);
    fee = _fee;

    tickSpacing = IUniswapV3Pool(_poolAddress).tickSpacing();

    (lowerTick, upperTick) = _returnLimitInTicks(_lowerLimit, _upperLimit);
  }

  function onERC721Received(
    address operator,
    address from,
    uint256 tokenId,
    bytes calldata data
  ) external override returns (bytes4) {
    // @TODO Get position information

    // Anyone can send an ERC721 to the contract so we need to lock it
    // in order to record the correct tokenId.
    if (locked) {
      tokenId = tokenId;
    }

    locked = false;

    // _createDeposit(operator, tokenId);
    return this.onERC721Received.selector;
  }

  function principal() external view returns (uint256 amount0, uint256 amount1) {
    (amount0, amount1) = _getPrincipal();
  }

  function unclaimedFees() external view returns (uint256 amount0, uint256 amount1) {
    (amount0, amount1) = _getFees();
  }

  function price() external view returns (uint256) {
    return _getPrice();
  }

  function oraclePrice(uint32 _seconds) public view returns (uint256) {
    return _oracleUintPrice(_seconds);
  }

  function prices() public view returns (uint256 priceToken0, uint256 priceToken1) {
    priceToken1 = _getPrice();
    priceToken0 = _priceToken0(priceToken1);
  }

  function oraclePrices(uint32 _seconds)
    public
    view
    returns (uint256 priceToken0, uint256 priceToken1)
  {
    priceToken1 = _oracleUintPrice(_seconds);
    priceToken0 = _priceToken0(priceToken1);
  }

  function lowerLimit() external view returns (uint256) {
    return _lowerLimit();
  }

  function upperLimit() external view returns (uint256) {
    return _upperLimit();
  }

  function addLiquidity(uint256 amount0, uint256 amount1) external {
    _addLiquidity(amount0, amount1);
  }

  function calculateDepositRatio(uint256 amount0, uint256 amount1)
    external
    view
    returns (uint256 _amount0, uint256 _amount1)
  {
    (_amount0, _amount1) = _calculateRatio(amount0, amount1);
  }

  function swap(
    address tokenIn,
    uint256 amountIn,
    uint16 slippage
  ) external returns (uint256 amountOut) {
    ERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

    return _swap(tokenIn, amountIn, slippage);
  }

  function _addLiquidity(uint256 _amount0, uint256 _amount1) internal {
    _convertToRatio(_amount0, _amount1, 50);

    // if (tokenId == 0) {
    //   _mint(_amount0, _amount1);
    // } else {
    //   _increaseLiquidity(_amount0, _amount1);
    // }
  }

  function _swap(
    address _tokenIn,
    uint256 _amountIn,
    uint16 _slippage
  ) internal returns (uint256 _amountOut) {
    require(
      _tokenIn == token0 || _tokenIn == token1,
      'RangePool: Only tokens from the pool are supported for swap'
    );

    uint16 resolution = 10_000;
    address tokenOut;
    _tokenIn == token0 ? tokenOut = token1 : tokenOut = token0;
    _tokenIn.safeApprove(address(router), _amountIn);

    uint256 expectedAmountOut = tokenOut == token0
      ? _convert1ToToken0(_amountIn, true)
      : _convert0ToToken1(_amountIn, true);

    console.log('Expected amount: ', expectedAmountOut);

    uint256 amountOutMinimum = expectedAmountOut - (expectedAmountOut * _slippage) / resolution;

    console.log('Amount out minimum: ', amountOutMinimum);

    uint160 sqrtPriceLimitX96 = _tokenIn == token1
      ? (_sqrtPriceX96() * _slippage) / resolution + _sqrtPriceX96()
      : _sqrtPriceX96() - (_sqrtPriceX96() * _slippage) / resolution;

    ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
      tokenIn: _tokenIn,
      tokenOut: tokenOut,
      fee: fee,
      recipient: address(this),
      deadline: block.timestamp,
      amountIn: _amountIn,
      amountOutMinimum: amountOutMinimum,
      sqrtPriceLimitX96: sqrtPriceLimitX96
    });

    _amountOut = router.exactInputSingle(params);
  }

  function _mint(uint256 _amount0, uint256 _amount1)
    internal
    returns (
      uint256 tokenId,
      uint128 liquidity,
      uint256 amount0,
      uint256 amount1
    )
  {
    locked = true;

    token0.safeApprove(address(NFPM), _amount0);
    token1.safeApprove(address(NFPM), _amount1);

    INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
      token0: token0,
      token1: token1,
      fee: fee,
      tickLower: lowerTick, //Tick needs to exist (right spacing)
      tickUpper: upperTick, //Tick needs to exist (right spacing)
      amount0Desired: _amount0,
      amount1Desired: _amount1,
      amount0Min: 0, // slippage check
      amount1Min: 0, // slippage check
      recipient: address(this), // receiver of ERC721
      deadline: block.timestamp
    });

    (tokenId, liquidity, amount0, amount1) = NFPM.mint(params);
  }

  function _increaseLiquidity(uint256 _amount0, uint256 _amount1) internal {}

  function _convertToRatio(
    uint256 _amount0,
    uint256 _amount1,
    uint16 _slippage
  ) internal returns (uint256 amount0, uint256 amount1) {
    ERC20(token0).transferFrom(msg.sender, address(this), _amount0);
    ERC20(token1).transferFrom(msg.sender, address(this), _amount1);

    (uint256 targetAmount0, uint256 targetAmount1) = _calculateRatio(_amount0, _amount1);

    amount0 = _amount0;
    amount1 = _amount1;
    uint256 diff;

    console.log('Target amount0: ', targetAmount0);
    console.log('Target amount1: ', targetAmount1);

    if (_amount0 > targetAmount0) {
      diff = _amount0 - targetAmount0;
      amount0 -= diff;
      amount1 += _swap(token0, diff, _slippage);
    }

    if (_amount1 > targetAmount1) {
      diff = _amount1 - targetAmount1;
      amount1 -= diff;
      amount0 += _swap(token1, diff, _slippage);
    }

    console.log('Balance of token 0: ', ERC20(token0).balanceOf(address(this)));
    console.log('Balance of token 1: ', ERC20(token1).balanceOf(address(this)));

    assert(ERC20(token0).balanceOf(address(this)) >= amount0);
    assert(ERC20(token1).balanceOf(address(this)) >= amount1);
  }

  function _calculateRatio(uint256 _amount0, uint256 _amount1)
    internal
    view
    returns (uint256 amount0, uint256 amount1)
  {
    uint256 sumInToken1 = _convert0ToToken1(_amount0, false) + _amount1;
    (uint256 amount0InToken1, uint256 _amount1) = _applyRatio(
      sumInToken1,
      _lowerLimit(),
      _upperLimit()
    );
    amount0 = _convert1ToToken0(amount0InToken1, false);
    amount1 = _amount1;
  }

  function _applyRatio(
    uint256 _amountSumInToken1,
    uint256 _lowerLimit,
    uint256 _upperLimit
  ) internal view returns (uint256 _ratio0InToken1, uint256 _ratio1) {
    uint16 precision = 10_000;
    (uint256 ratio0, uint256 ratio1) = _getRatioForLiquidity(_lowerLimit, _upperLimit, precision);
    _ratio0InToken1 = (_amountSumInToken1 * ratio0) / precision;
    _ratio1 = (_amountSumInToken1 * ratio1) / precision;
  }

  function _getRatioForLiquidity(
    uint256 _lowerLimit,
    uint256 _upperLimit,
    uint16 _precision
  ) internal view returns (uint256 _ratioToken0, uint256 _ratioToken1) {
    (uint256 amount0, uint256 amount1) = _getAmountsForLiquidity(_lowerLimit, _upperLimit);
    uint256 amount0ConvertedToToken1 = _convert0ToToken1(amount0, false);
    uint256 sum = amount0ConvertedToToken1 + amount1;
    _ratioToken0 = (amount0ConvertedToToken1 * _precision) / sum;
    _ratioToken1 = (amount1 * _precision) / sum;
  }

  function _priceToken0(uint256 _priceToken1) internal view returns (uint256) {
    uint8 decimalsToken0 = ERC20(token0).decimals();
    uint8 decimalsToken1 = ERC20(token1).decimals();
    return 10**(decimalsToken0 + decimalsToken1) / _priceToken1;
  }

  function _convert0ToToken1(uint256 amount0, bool useOracle)
    internal
    view
    returns (uint256 amount0ConvertedToToken1)
  {
    uint256 price = useOracle ? _oracleUintPrice(60) : _getPrice();

    amount0ConvertedToToken1 = (amount0 * price) / 10**ERC20(token0).decimals();
  }

  function _convert1ToToken0(uint256 amount1, bool useOracle)
    internal
    view
    returns (uint256 amount1ConvertedToToken0)
  {
    uint256 price = useOracle ? _oracleUintPrice(60) : _getPrice();

    amount1ConvertedToToken0 = (amount1 * 10**ERC20(token0).decimals()) / price;
  }

  function _getAmountsForLiquidity(uint256 _lowerLimit, uint256 _upperLimit)
    internal
    view
    returns (uint256 _amount0, uint256 _amount1)
  {
    // Convert the manual entered range to ticks and then to sqrtPriceX96 in order to
    // utilize the available price range relative to tick spacing.
    (int24 lowerTick, int24 upperTick) = _returnLimitInTicks(_lowerLimit, _upperLimit);

    uint160 lowerLimitSqrtPricex96 = TickMath.getSqrtRatioAtTick(lowerTick);
    uint160 upperLimitSqrtPricex96 = TickMath.getSqrtRatioAtTick(upperTick);

    (_amount0, _amount1) = LiquidityAmounts.getAmountsForLiquidity(
      _sqrtPriceX96(),
      lowerLimitSqrtPricex96,
      upperLimitSqrtPricex96,
      IUniswapV3Pool(pool).liquidity()
    );
  }

  function _returnLimitInTicks(uint256 lowerLimit, uint256 upperLimit)
    internal
    view
    returns (int24 lowerTick, int24 upperTick)
  {
    int24 tickL = _getValidatedTickNumber(lowerLimit, ERC20(token0).decimals(), tickSpacing);
    int24 tickU = _getValidatedTickNumber(upperLimit, ERC20(token0).decimals(), tickSpacing);
    (lowerTick, upperTick) = Utils.orderTicks(tickL, tickU);
  }

  function _getValidatedTickNumber(
    uint256 price,
    uint8 decimalsToken0,
    int24 tickSpacing
  ) internal pure returns (int24) {
    int24 tick = TickMath.getTickAtSqrtRatio(Conversions.uintToSqrtPriceX96(price, decimalsToken0));
    return _validateTick(tick, tickSpacing);
  }

  function _validateTick(int24 tick, int24 tickSpacing) internal pure returns (int24) {
    return (tick / tickSpacing) * tickSpacing;
  }

  function _lowerLimit() internal view returns (uint256) {
    return
      Conversions.sqrtPriceX96ToUint(
        TickMath.getSqrtRatioAtTick(lowerTick),
        ERC20(token0).decimals()
      );
  }

  function _upperLimit() internal view returns (uint256) {
    return
      Conversions.sqrtPriceX96ToUint(
        TickMath.getSqrtRatioAtTick(upperTick),
        ERC20(token0).decimals()
      );
  }

  function _getPrice() internal view returns (uint256) {
    return Conversions.sqrtPriceX96ToUint(_sqrtPriceX96(), ERC20(token0).decimals());
  }

  function _oracleUintPrice(uint32 _seconds) internal view returns (uint256) {
    return Conversions.sqrtPriceX96ToUint(_oracleSqrtPricex96(_seconds), ERC20(token0).decimals());
  }

  function _oracleSqrtPricex96(uint32 _seconds) internal view returns (uint160) {
    (int24 arithmeticMeanTick, ) = OracleLibrary.consult(pool, _seconds);
    return TickMath.getSqrtRatioAtTick(arithmeticMeanTick);
  }

  function _sqrtPriceX96() internal view returns (uint160 sqrtPriceX96) {
    (sqrtPriceX96, , , , , , ) = IUniswapV3Pool(pool).slot0();
  }

  // Get principal from a specific position.
  function _getPrincipal() internal view returns (uint256 amount0, uint256 amount1) {
    (amount0, amount1) = NFPM.principal(tokenId, _sqrtPriceX96());
  }

  // Get unclaimed fees from range.
  function _getFees() internal view returns (uint256 amount0, uint256 amount1) {
    (amount0, amount1) = NFPM.fees(tokenId);
  }
}
