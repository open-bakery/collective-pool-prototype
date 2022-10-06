// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;

import 'forge-std/Test.sol';

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

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
import './LP.sol';

// All prices and ranges in Uniswap are denominated in token1 (y) relative to token0 (x): (y/x as in x*y=k)
//Contract responsible for creating new pools.
contract RangePool is IERC721Receiver, Test {
  using PositionValue for NonfungiblePositionManager;
  using TransferHelper for address;
  using SafeERC20 for ERC20;
  using SafeMath for uint256;

  address public constant uniswapFactory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
  ISwapRouter public constant router = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
  NonfungiblePositionManager public constant NFPM =
    NonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

  LP public lpToken;
  address public token0;
  address public token1;
  address public pool;
  uint24 public fee;
  int24 public lowerTick;
  int24 public upperTick;
  int24 public tickSpacing;
  uint256 public tokenId;

  uint16 constant resolution = 10_000;

  constructor(
    address _tokenA,
    address _tokenB,
    uint24 _fee,
    uint256 _lowerLimit,
    uint256 _upperLimit
  ) {
    require(_lowerLimit < _upperLimit, 'RangePool: _lowerLimit must be lower than _upperLimit');

    pool = Utils.getPoolAddress(_tokenA, _tokenB, _fee, uniswapFactory);
    (token0, token1) = Utils.orderTokens(_tokenA, _tokenB);
    fee = _fee;
    tickSpacing = IUniswapV3Pool(pool).tickSpacing();

    if (_lowerLimit == 0) _lowerLimit = 1;
    (lowerTick, upperTick) = _returnLimitInTicks(_lowerLimit, _upperLimit);
  }

  function onERC721Received(
    address operator,
    address from,
    uint256 id,
    bytes calldata data
  ) external override returns (bytes4) {
    console.log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
    console.log('onERC721Received() Function Call');
    console.log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');

    return this.onERC721Received.selector;
  }

  function principal() external view returns (uint256 amount0, uint256 amount1) {
    (amount0, amount1) = _getPrincipal();
  }

  function unclaimedFees() external view returns (uint256 amount0, uint256 amount1) {
    (amount0, amount1) = _getFees();
  }

  function sqrtPriceX96() external view returns (uint160) {
    return _sqrtPriceX96();
  }

  function price() external view returns (uint256) {
    return _getPrice();
  }

  function priceFromLiquidity() external view returns (uint256) {
    return _getPriceFromLiquidity();
  }

  function oraclePrice(uint32 secondsElapsed) external view returns (uint256) {
    return _oracleUintPrice(secondsElapsed);
  }

  function prices() external view returns (uint256 priceToken0, uint256 priceToken1) {
    priceToken1 = _getPrice();
    priceToken0 = _priceToken0(priceToken1);
  }

  function pricesFromLiquidity() external view returns (uint256 priceToken0, uint256 priceToken1) {
    priceToken1 = _getPriceFromLiquidity();
    priceToken0 = _priceToken0(priceToken1);
  }

  function oraclePrices(uint32 secondsElapsed)
    external
    view
    returns (uint256 priceToken0, uint256 priceToken1)
  {
    priceToken1 = _oracleUintPrice(secondsElapsed);
    priceToken0 = _priceToken0(priceToken1);
  }

  function accumulatedFees() external view returns (uint256 amount0, uint256 amount1) {
    (amount0, amount1) = NFPM.fees(tokenId);
  }

  function lowerLimit() external view returns (uint256) {
    return _getLowerLimit();
  }

  function upperLimit() external view returns (uint256) {
    return _getUpperLimit();
  }

  function addLiquidity(
    uint256 amount0,
    uint256 amount1,
    uint16 slippage
  ) external {
    _addLiquidity(msg.sender, amount0, amount1, slippage);
  }

  function decreaseLiquidity(uint128 liquidity, uint16 slippage)
    external
    returns (uint256 amount0Decreased, uint256 amount1Decreased)
  {
    (amount0Decreased, amount1Decreased) = _decreaseLiquidity(msg.sender, liquidity, slippage);
  }

  function calculateDepositRatio(uint256 amount0, uint256 amount1)
    external
    view
    returns (uint256 amount0Ratioed, uint256 amount1Ratioed)
  {
    (amount0Ratioed, amount1Ratioed) = _calculateRatio(amount0, amount1);
  }

  function swap(
    address tokenIn,
    uint256 amountIn,
    uint16 slippage
  ) external returns (uint256 amountOut) {
    ERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

    return _swap(tokenIn, amountIn, slippage);
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

    address tokenOut;
    _tokenIn == token0 ? tokenOut = token1 : tokenOut = token0;
    _tokenIn.safeApprove(address(router), _amountIn);

    uint256 expectedAmountOut = tokenOut == token0
      ? _convert1ToToken0(_amountIn, true)
      : _convert0ToToken1(_amountIn, true);

    uint256 amountOutMinimum = _applySlippageTolerance(false, expectedAmountOut, _slippage);

    uint160 sqrtPriceLimitX96 = _tokenIn == token1
      ? uint160(_applySlippageTolerance(true, uint256(_sqrtPriceX96()), _slippage))
      : uint160(_applySlippageTolerance(false, uint256(_sqrtPriceX96()), _slippage));

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

    console.log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
    console.log('_swap() Function Call');
    console.log('expectedAmountOut: ', expectedAmountOut);
    console.log('amountOutMinimum: ', amountOutMinimum);
    console.log('_amountOut: ', _amountOut);
    console.log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
  }

  function _mint(
    address _account,
    uint256 _amount0,
    uint256 _amount1,
    uint16 _slippage
  )
    internal
    returns (
      uint256 _generatedTokenId,
      uint128 _liquidityAdded,
      uint256 _amount0Received,
      uint256 _amount1Received
    )
  {
    token0.safeApprove(address(NFPM), type(uint256).max);
    token1.safeApprove(address(NFPM), type(uint256).max);

    uint256 amount0MinAccepted = _applySlippageTolerance(false, _amount0, _slippage);
    uint256 amount1MinAccepted = _applySlippageTolerance(false, _amount1, _slippage);

    INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
      token0: token0,
      token1: token1,
      fee: fee,
      tickLower: lowerTick, //Tick needs to exist (right spacing)
      tickUpper: upperTick, //Tick needs to exist (right spacing)
      amount0Desired: _amount0,
      amount1Desired: _amount1,
      amount0Min: amount0MinAccepted, // slippage check
      amount1Min: amount1MinAccepted, // slippage check
      recipient: address(this), // receiver of ERC721
      deadline: block.timestamp
    });

    (_generatedTokenId, _liquidityAdded, _amount0Received, _amount1Received) = NFPM.mint(params);

    if (address(lpToken) == address(0)) lpToken = new LP(_generatedTokenId);
    lpToken.mint(_account, _liquidityAdded);
  }

  function _addLiquidity(
    address _account,
    uint256 _amount0,
    uint256 _amount1,
    uint16 _slippage
  ) internal {
    (uint256 amount0Ratioed, uint256 amount1Ratioed) = _convertToRatio(_amount0, _amount1, 50);

    if (tokenId == 0) {
      (uint256 id, uint128 addedLiquidity, uint256 addedAmount0, uint256 addedAmount1) = _mint(
        _account,
        amount0Ratioed,
        amount1Ratioed,
        _slippage
      );

      tokenId = id;

      uint256 refund0 = amount0Ratioed.sub(addedAmount0);
      uint256 refund1 = amount1Ratioed.sub(addedAmount1);
      if (refund0 != 0) ERC20(token0).safeTransfer(_account, refund0);
      if (refund1 != 0) ERC20(token1).safeTransfer(_account, refund1);

      console.log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
      console.log('_addLiquidity() Function Call');
      console.log('addedLiquidity: ', addedLiquidity);
      console.log('addedAmount0: ', addedAmount0);
      console.log('addedAmount1: ', addedAmount1);
      console.log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
    } else {
      _increaseLiquidity(_account, amount0Ratioed, amount1Ratioed, _slippage);
    }
  }

  function _increaseLiquidity(
    address _account,
    uint256 _amount0,
    uint256 _amount1,
    uint16 _slippage
  )
    internal
    returns (
      uint128 _liquidityIncreased,
      uint256 _amount0Increased,
      uint256 _amount1Increased
    )
  {
    uint256 amount0MinAccepted = _applySlippageTolerance(false, _amount0, _slippage);
    uint256 amount1MinAccepted = _applySlippageTolerance(false, _amount1, _slippage);

    INonfungiblePositionManager.IncreaseLiquidityParams memory params = INonfungiblePositionManager
      .IncreaseLiquidityParams({
        tokenId: tokenId,
        amount0Desired: _amount0,
        amount1Desired: _amount1,
        amount0Min: amount0MinAccepted,
        amount1Min: amount1MinAccepted,
        deadline: block.timestamp
      });

    (_liquidityIncreased, _amount0Increased, _amount1Increased) = NFPM.increaseLiquidity(params);

    lpToken.mint(_account, uint256(_liquidityIncreased));

    console.log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
    console.log('_increaseLiquidity() Function Call');
    console.log('_amount0: ', _amount0);
    console.log('_amount1: ', _amount1);
    console.log('amount0MinAccepted: ', amount0MinAccepted);
    console.log('amount1MinAccepted: ', amount1MinAccepted);
    console.log('_amount0Increased: ', _amount0Increased);
    console.log('_amount1Increased: ', _amount1Increased);
    console.log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
  }

  function _decreaseLiquidity(
    address _account,
    uint128 _liquidity,
    uint16 _slippage
  ) internal returns (uint256 _amount0Decreased, uint256 _amount1Decreased) {
    require(lpToken.balanceOf(_account) >= _liquidity, 'RangePool: Not enough liquidity');

    uint32 _seconds = 60;

    (uint256 _expectedAmount0, uint256 _expectedAmount1) = LiquidityAmounts.getAmountsForLiquidity(
      _oracleSqrtPricex96(_seconds),
      TickMath.getSqrtRatioAtTick(lowerTick),
      TickMath.getSqrtRatioAtTick(upperTick),
      _liquidity
    );

    uint256 amount0Min = _applySlippageTolerance(false, _expectedAmount0, _slippage);
    uint256 amount1Min = _applySlippageTolerance(false, _expectedAmount1, _slippage);

    INonfungiblePositionManager.DecreaseLiquidityParams memory params = INonfungiblePositionManager
      .DecreaseLiquidityParams({
        tokenId: tokenId,
        liquidity: _liquidity,
        amount0Min: amount0Min,
        amount1Min: amount1Min,
        deadline: block.timestamp
      });

    lpToken.burn(_account, uint256(_liquidity));
    (_amount0Decreased, _amount1Decreased) = NFPM.decreaseLiquidity(params);
    _collect(_account, uint128(_amount0Decreased), uint128(_amount1Decreased));

    console.log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
    console.log('_decreaseLiquidity() Function Call');
    console.log('_expectedAmount0: ', _expectedAmount0);
    console.log('_expectedAmount1: ', _expectedAmount1);
    console.log('amount0Min: ', amount0Min);
    console.log('amount1Min: ', amount1Min);
    console.log('amount0Decreased: ', _amount0Decreased);
    console.log('amount1Decreased: ', _amount1Decreased);
    console.log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
  }

  function _collect(
    address _account,
    uint128 _amount0,
    uint128 _amount1
  ) internal returns (uint256 amount0Collected, uint256 amount1Collected) {
    INonfungiblePositionManager.CollectParams memory params = INonfungiblePositionManager
      .CollectParams({
        tokenId: tokenId,
        recipient: _account,
        amount0Max: _amount0,
        amount1Max: _amount1
      });

    (amount0Collected, amount1Collected) = NFPM.collect(params);
  }

  function _collectFees(address _account)
    internal
    returns (uint256 amount0Collected, uint256 amount1Collected)
  {
    (uint256 feeAmount0, uint256 feeAmount1) = NFPM.fees(tokenId);
    (amount0Collected, amount1Collected) = _collect(
      _account,
      uint128(feeAmount0),
      uint128(feeAmount1)
    );
  }

  function _burn() internal {}

  function _applySlippageTolerance(
    bool _positive,
    uint256 _amount,
    uint16 _slippage
  ) internal pure returns (uint256 _amountAccepted) {
    _amountAccepted = _positive
      ? (_amount.mul(_slippage).div(resolution)).add(_amount)
      : _amount.sub(_amount.mul(_slippage).div(resolution));
  }

  function _convertToRatio(
    uint256 _amount0,
    uint256 _amount1,
    uint16 _slippage
  ) internal returns (uint256 amount0, uint256 amount1) {
    ERC20(token0).safeTransferFrom(msg.sender, address(this), _amount0);
    ERC20(token1).safeTransferFrom(msg.sender, address(this), _amount1);

    (uint256 targetAmount0, uint256 targetAmount1) = _calculateRatio(_amount0, _amount1);

    amount0 = _amount0;
    amount1 = _amount1;
    uint256 diff;

    if (_amount0 > targetAmount0) {
      diff = _amount0.sub(targetAmount0);
      amount0 = amount0.sub(diff);
      amount1 = amount1.add(_swap(token0, diff, _slippage));
    }

    if (_amount1 > targetAmount1) {
      diff = _amount1.sub(targetAmount1);
      amount1 = amount1.sub(diff);
      amount0 = amount0.add(_swap(token1, diff, _slippage));
    }

    console.log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
    console.log('_convertRatio() Function Call');
    console.log('targetAmount0: ', targetAmount0);
    console.log('targetAmount1: ', targetAmount1);
    console.log('token0.balanceOf(address(this)): ', ERC20(token0).balanceOf(address(this)));
    console.log('amount0: ', amount0);
    console.log('token1.balanceOf(address(this)) ', ERC20(token1).balanceOf(address(this)));
    console.log('amount1: ', amount1);
    console.log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');

    assert(ERC20(token0).balanceOf(address(this)) >= amount0);
    assert(ERC20(token1).balanceOf(address(this)) >= amount1);
  }

  function _calculateRatio(uint256 _amount0, uint256 _amount1)
    internal
    view
    returns (uint256 amount0Ratioed, uint256 amount1Ratioed)
  {
    uint256 sumConvertedToToken1 = _convert0ToToken1(_amount0, false).add(_amount1);
    (uint256 amount0ConvertedToToken1, uint256 amount1) = _applyRatio(
      sumConvertedToToken1,
      _getLowerLimit(),
      _getUpperLimit()
    );
    amount0Ratioed = _convert1ToToken0(amount0ConvertedToToken1, false);
    amount1Ratioed = amount1;
  }

  function _applyRatio(
    uint256 _amountSumInToken1,
    uint256 _lowerLimit,
    uint256 _upperLimit
  ) internal view returns (uint256 _ratio0InToken1, uint256 _ratio1) {
    uint16 precision = 10_000;
    (uint256 ratio0, uint256 ratio1) = _getRatioForLiquidity(_lowerLimit, _upperLimit, precision);
    _ratio0InToken1 = _amountSumInToken1.mul(ratio0).div(precision);
    _ratio1 = _amountSumInToken1.mul(ratio1).div(precision);
  }

  function _getRatioForLiquidity(
    uint256 _lowerLimit,
    uint256 _upperLimit,
    uint16 _precision
  ) internal view returns (uint256 _ratioToken0, uint256 _ratioToken1) {
    (uint256 amount0, uint256 amount1) = _getAmountsForLiquidity(_lowerLimit, _upperLimit);
    uint256 amount0ConvertedToToken1 = _convert0ToToken1(amount0, false);
    uint256 sum = amount0ConvertedToToken1.add(amount1);
    _ratioToken0 = amount0ConvertedToToken1.mul(_precision).div(sum);
    _ratioToken1 = amount1.mul(_precision).div(sum);
  }

  function _priceToken0(uint256 _priceToken1) internal view returns (uint256) {
    uint8 decimalsToken0 = ERC20(token0).decimals();
    uint8 decimalsToken1 = ERC20(token1).decimals();
    return (10**(SafeMath.add(decimalsToken0, decimalsToken1))).div(_priceToken1);
  }

  function _convert0ToToken1(uint256 amount0, bool useOracle)
    internal
    view
    returns (uint256 amount0ConvertedToToken1)
  {
    uint256 price = useOracle ? _oracleUintPrice(60) : _getPrice();

    amount0ConvertedToToken1 = amount0.mul(price).div(10**ERC20(token0).decimals());
  }

  function _convert1ToToken0(uint256 amount1, bool useOracle)
    internal
    view
    returns (uint256 amount1ConvertedToToken0)
  {
    uint256 price = useOracle ? _oracleUintPrice(60) : _getPrice();

    amount1ConvertedToToken0 = amount1.mul(10**ERC20(token0).decimals()).div(price);
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
    console.log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
    console.log('_returnLimitInTicks Function Call');
    console.log('tickL: ');
    console.logInt(tickL);
    console.log('tickU: ');
    console.logInt(tickU);
    console.log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
  }

  function _getValidatedTickNumber(
    uint256 price,
    uint8 decimalsToken0,
    int24 tickSpacing
  ) internal pure returns (int24) {
    int24 tick = TickMath.getTickAtSqrtRatio(Conversions.uintToSqrtPriceX96(price, decimalsToken0));
    return _validateTick(tick, tickSpacing);
  }

  function _validateTick(int24 _tick, int24 _tickSpacing) internal pure returns (int24) {
    if (_tickSpacing == 0) _tickSpacing = 1;
    return (_tick / _tickSpacing) * _tickSpacing;
  }

  function _getLowerLimit() internal view returns (uint256) {
    return
      Conversions.sqrtPriceX96ToUint(
        TickMath.getSqrtRatioAtTick(lowerTick),
        ERC20(token0).decimals()
      );
  }

  function _getUpperLimit() internal view returns (uint256) {
    return
      Conversions.sqrtPriceX96ToUint(
        TickMath.getSqrtRatioAtTick(upperTick),
        ERC20(token0).decimals()
      );
  }

  function _getPriceFromLiquidity() internal view returns (uint256) {
    uint256 amount0 = FullMath.mulDiv(
      IUniswapV3Pool(pool).liquidity(),
      FixedPoint96.Q96,
      _sqrtPriceX96()
    );
    uint256 amount1 = FullMath.mulDiv(
      IUniswapV3Pool(pool).liquidity(),
      _sqrtPriceX96(),
      FixedPoint96.Q96
    );

    console.log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
    console.log('_getPrice() Function Call');
    console.log('amount0: ', amount0);
    console.log('amount1: ', amount1);
    console.log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');

    return (amount1.mul(10**ERC20(token0).decimals())).div(amount0);
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
