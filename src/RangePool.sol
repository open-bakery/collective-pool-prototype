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
import '@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol';

// All prices and ranges in Uniswap are denominated in token1 (y) relative to token0 (x): (y/x as in x*y=k)
//Contract responsible for creating new pools.
contract RangePool is IERC721Receiver, Test {
  using PositionValue for NonfungiblePositionManager;
  using TransferHelper for address;

  address public constant uniswapFactory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
  address public immutable token0;
  address public immutable token1;
  address public immutable pool;
  uint24 public immutable fee;
  int24 public immutable tickSpacing;

  uint256 public tokenId;
  uint256 public lowerRange;
  uint256 public upperRange;
  bool initialized;

  ISwapRouter public constant router = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
  NonfungiblePositionManager public constant NFPM =
    NonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

  struct Deposit {
    address owner;
    uint128 liquidity;
    address token0;
    address token1;
  }

  mapping(uint256 => Deposit) public deposits;

  modifier nonInitialized() {
    require(!initialized, 'RangePool: Range can only be initialized once.');
    _;
  }

  constructor(
    address _tokenA,
    address _tokenB,
    uint24 _fee
  ) {
    address _poolAddress = _getPoolAddress(_tokenA, _tokenB, _fee);
    pool = _poolAddress;
    (token0, token1) = _orderTokens(_tokenA, _tokenB);
    fee = _fee;
    tickSpacing = IUniswapV3Pool(_poolAddress).tickSpacing();
  }

  function initialize(uint256 lowerRange, uint256 upperRange)
    external
    nonInitialized
    returns (bool)
  {
    // code to mint a position here.
    initialized = true;
  }

  function onERC721Received(
    address operator,
    address from,
    uint256 tokenId,
    bytes calldata data
  ) external override returns (bytes4) {
    // get position information

    // TODO Implement multiple positions
    // Anyone can send an ERC721 to the contract.
    if (msg.sender == address(NFPM) && tokenId == 0) {
      tokenId = tokenId;
    }

    // _createDeposit(operator, tokenId);
    return this.onERC721Received.selector;
  }

  function principal() external view returns (uint256 amount0, uint256 amount1) {
    (amount0, amount1) = _getPrincipal();
  }

  function unclaimedFees() external view returns (uint256 amount0, uint256 amount1) {
    (amount0, amount1) = _getFees();
  }

  function oraclePrice(uint32 _seconds) public view returns (uint256) {
    return _oracleUintPrice(_seconds);
  }

  function price() external view returns (uint256) {
    return _getPrice();
  }

  function prices() public view returns (uint256 priceToken0, uint256 priceToken1) {
    uint8 decimalsToken0 = ERC20(token0).decimals();
    uint8 decimalsToken1 = ERC20(token1).decimals();

    priceToken1 = _getPrice();
    priceToken0 = 10**(decimalsToken0 + decimalsToken1) / priceToken1;
  }

  function calculateCorrectDepositRatio(
    uint256 amount0,
    uint256 amount1,
    uint256 lowerRange,
    uint256 upperRange
  ) public view returns (uint256 _amount0, uint256 _amount1) {
    uint256 sumInToken1 = _conver0ToToken1(amount0) + amount1;
    (uint256 amount0InToken1, uint256 amount1) = _applyRatio(sumInToken1, lowerRange, upperRange);
    _amount0 = _conver1ToToken0(amount0InToken1);
    _amount1 = amount1;
  }

  function _applyRatio(
    uint256 _amountSumInToken1,
    uint256 _lowerRange,
    uint256 _upperRange
  ) internal view returns (uint256 _ratio0InToken1, uint256 _ratio1) {
    uint16 precision = 10_000;
    (uint256 ratio0, uint256 ratio1) = _getRatioForLiquidity(_lowerRange, _upperRange, precision);
    _ratio0InToken1 = (_amountSumInToken1 * ratio0) / precision;
    _ratio1 = (_amountSumInToken1 * ratio1) / precision;
  }

  function _getRatioForLiquidity(
    uint256 _lowerRange,
    uint256 _upperRange,
    uint16 _precision
  ) internal view returns (uint256 _ratioToken0, uint256 _ratioToken1) {
    (uint256 amount0, uint256 amount1) = _getAmountsForLiquidity(_lowerRange, _upperRange);
    uint256 amount0ConvertedToToken1 = _conver0ToToken1(amount0);
    uint256 sum = amount0ConvertedToToken1 + amount1;
    _ratioToken0 = (amount0ConvertedToToken1 * _precision) / sum;
    _ratioToken1 = (amount1 * _precision) / sum;
  }

  function _conver0ToToken1(uint256 amount0)
    internal
    view
    returns (uint256 amount0ConvertedToToken1)
  {
    amount0ConvertedToToken1 = (amount0 * _getPrice()) / 10**ERC20(token0).decimals();
  }

  function _conver1ToToken0(uint256 amount1)
    internal
    view
    returns (uint256 amount1ConvertedToToken0)
  {
    amount1ConvertedToToken0 = (amount1 * 10**ERC20(token0).decimals()) / _getPrice();
  }

  function _getAmountsForLiquidity(uint256 _lowerRange, uint256 _upperRange)
    internal
    view
    returns (uint256 _amount0, uint256 _amount1)
  {
    // Convert the manual entered range to ticks and then to sqrtPriceX96 in order to
    // utilize the available price range relative to tick spacing.
    (int24 lowerTick, int24 upperTick) = _returnRangeInTicks(_lowerRange, _upperRange);

    uint160 lowerRangeSqrtPricex96 = TickMath.getSqrtRatioAtTick(lowerTick);
    uint160 upperRangeSqrtPricex96 = TickMath.getSqrtRatioAtTick(upperTick);

    (_amount0, _amount1) = LiquidityAmounts.getAmountsForLiquidity(
      _sqrtPriceX96(),
      lowerRangeSqrtPricex96,
      upperRangeSqrtPricex96,
      IUniswapV3Pool(pool).liquidity()
    );
  }

  function _returnRangeInTicks(uint256 lowerRange, uint256 upperRange)
    internal
    view
    returns (int24 lowerTick, int24 upperTick)
  {
    int24 tickSpacing = IUniswapV3Pool(pool).tickSpacing();

    int24 tickL = _getTickNumber(lowerRange, ERC20(token0).decimals(), tickSpacing);
    int24 tickU = _getTickNumber(upperRange, ERC20(token0).decimals(), tickSpacing);
    (lowerTick, upperTick) = _orderTick(tickL, tickU);
  }

  function _orderTick(int24 tick0, int24 tick1)
    internal
    pure
    returns (int24 tickLower, int24 tickUpper)
  {
    (tickLower, tickUpper) = tick1 < tick0 ? (tick1, tick0) : (tick0, tick1);
  }

  function _roundTick(int24 tick, int24 tickSpacing) internal pure returns (int24) {
    return (tick / tickSpacing) * tickSpacing;
  }

  function _getTickNumber(
    uint256 price,
    uint8 decimalsToken0,
    int24 tickSpacing
  ) internal pure returns (int24) {
    int24 tick = TickMath.getTickAtSqrtRatio(_uintToSqrtPriceX96(price, decimalsToken0));
    int24 validTick = _roundTick(tick, tickSpacing);
    return validTick;
  }

  function _getPrice() internal view returns (uint256) {
    return _sqrtPriceX96ToUint(_sqrtPriceX96(), ERC20(token0).decimals());
  }

  function _oracleUintPrice(uint32 _seconds) internal view returns (uint256) {
    return _sqrtPriceX96ToUint(_oracleSqrtPricex96(_seconds), ERC20(token0).decimals());
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

  function _getPoolAddress(
    address _tokenA,
    address _tokenB,
    uint24 _fee
  ) internal pure returns (address) {
    return
      PoolAddress.computeAddress(uniswapFactory, PoolAddress.getPoolKey(_tokenA, _tokenB, _fee));
  }

  // Uniswap's default is price=y/x, this means that the sqrtPriceX96 from a pool contract
  // will always be of the price of token1 relative to token0.
  function _sqrtPriceX96ToUint(uint160 sqrtPriceX96, uint8 decimalsToken0)
    internal
    pure
    returns (uint256)
  {
    uint256 a = uint256(sqrtPriceX96) * uint256(sqrtPriceX96) * 10**decimalsToken0;
    uint256 b = (96 * 2);
    return a >> b;
  }

  // Uniswap's default is price=y/x, this means that the price one gets is always the amount of token1 relative to token 0.
  function _uintToSqrtPriceX96(uint256 priceToken1, uint8 decimalsToken0)
    internal
    pure
    returns (uint160)
  {
    uint256 ratioX192 = (priceToken1 << 192) / 10**decimalsToken0;
    return uint160(_sqrt(ratioX192));
  }

  function _orderTokens(address tokenA, address tokenB)
    internal
    pure
    returns (address token0, address token1)
  {
    require(tokenA != tokenB);
    (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
  }

  function _sqrt(uint256 x) internal pure returns (uint256 y) {
    uint256 z = (x + 1) / 2;
    y = x;
    while (z < y) {
      y = z;
      z = (x / z + z) / 2;
    }
  }
}
