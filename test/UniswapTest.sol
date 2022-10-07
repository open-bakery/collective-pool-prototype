// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.9.0;
pragma abicoder v2;

import 'forge-std/Test.sol';

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import '@uniswap/v3-core/contracts/libraries/FixedPoint96.sol';

import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol';
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import '@uniswap/v3-periphery/contracts/NonfungiblePositionManager.sol';

import '@uniswap/v3-periphery/contracts/libraries/PositionValue.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import '@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol';
import '@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol';

import '../src/RangePool.sol';
import '../src/PoolFactory.sol';
import '../src/libraries/Conversions.sol';

contract UniswapTest is Test {
  using PositionValue for NonfungiblePositionManager;
  using TransferHelper for address;

  IUniswapV3Factory factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
  NonfungiblePositionManager NFPM =
    NonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
  ISwapRouter router = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

  address ARB_WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
  address ARB_USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
  address ARB_GMX = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a;
  address MAIN_WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address MAIN_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

  struct Deposit {
    address owner;
    uint128 liquidity;
    address token0;
    address token1;
  }

  mapping(uint256 => Deposit) deposits;

  function setUp() public {}

  function testArbitrum() public {
    // scenario01(ARB_WETH, 5 ether, ARB_USDC, 20000_000000, 500);
    fullLogs(ARB_WETH, 5 ether, ARB_USDC, 2000_000000, 500);
  }

  function testMainnet() public {
    // scenario01(MAIN_WETH, 3 ether, MAIN_USDC, 2400_000000, 500);
    fullLogs(MAIN_WETH, 3 ether, MAIN_USDC, 2400_000000, 500);
  }

  function testAnvil() public returns (uint256) {}

  function initialize(
    address tokenA,
    uint256 amountA,
    address tokenB,
    uint256 amountB,
    uint24 fee
  )
    public
    returns (
      RangePool rangePool,
      uint256 amount0,
      uint256 amount1
    )
  {
    IUniswapV3Pool pool = IUniswapV3Pool(factory.getPool(tokenA, tokenB, fee));
    address token0 = pool.token0();
    address token1 = pool.token1();
    (amount0, amount1) = token0 != tokenA ? (amountB, amountA) : (amountA, amountB);

    (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(pool).slot0();
    uint256 price = Conversions.sqrtPriceX96ToUint(sqrtPriceX96, ERC20(pool.token0()).decimals());
    rangePool = new RangePool(token0, token1, fee, price / 3, price * 2);

    ERC20(tokenA).approve(address(rangePool), type(uint256).max);
    ERC20(tokenB).approve(address(rangePool), type(uint256).max);

    deal(address(token0), address(this), amount0);
    deal(address(token1), address(this), amount1);
  }

  function scenario01(
    address tokenA,
    uint256 amountA,
    address tokenB,
    uint256 amountB,
    uint24 fee
  ) public {
    (RangePool rangePool, uint256 amount0, uint256 amount1) = initialize(
      tokenA,
      amountA,
      tokenB,
      amountB,
      fee
    );

    uint16 slippage = 5_00;
    rangePool.addLiquidity(amount0, amount1, slippage);

    ERC20(rangePool.lpToken()).approve(address(rangePool), type(uint256).max);

    (uint256 amount0Decreased, uint256 amount1Decreased) = rangePool.decreaseLiquidity(
      uint128(ERC20(rangePool.lpToken()).balanceOf(address(this)) / 2),
      slippage
    );

    rangePool.addLiquidity(amount0Decreased, amount1Decreased, slippage);
  }

  function fullLogs(
    address tokenA,
    uint256 amountA,
    address tokenB,
    uint256 amountB,
    uint24 fee
  ) public {
    (RangePool rangePool, uint256 amount0, uint256 amount1) = initialize(
      tokenA,
      amountA,
      tokenB,
      amountB,
      fee
    );

    uint16 slippage = 5_00;
    rangePool.addLiquidity(amount0, amount1, slippage);

    logPrices(rangePool);
    logLimits(rangePool);
    logAveragePrices(rangePool);
  }

  function logAveragePrices(RangePool rangePool) public view {
    uint256 price0 = rangePool.averagePriceAtLowerLimit();
    uint256 price1 = rangePool.averagePriceAtUpperLimit();

    console.log('---------------------------------------');
    console.log('logAveragePrices() Function Call');
    console.log('price0: ', price0);
    console.log('price1: ', price1);
    console.log('---------------------------------------');
  }

  function logTokenAmountsAtLimits(RangePool rangePool) public view {
    (uint256 lowerAmount0, uint256 lowerAmount1) = rangePool.tokenAmountsAtLowerLimit(
      address(this)
    );
    (uint256 upperAmount0, uint256 upperAmount1) = rangePool.tokenAmountsAtUpperLimit(
      address(this)
    );

    console.log('---------------------------------------');
    console.log('logTokenAmountsAtLimits() Function Call');
    console.log('lowerAmount0: ', lowerAmount0);
    console.log('lowerAmount1: ', lowerAmount1);
    console.log('upperAmount0: ', upperAmount0);
    console.log('upperAmount1: ', upperAmount1);
    console.log('---------------------------------------');
  }

  function logRatios(
    RangePool rangePool,
    uint256 amount0,
    uint256 amount1
  ) public view {
    (uint256 output0, uint256 output1) = rangePool.calculateDepositRatio(amount0, amount1);
    console.log('Amount0 to deposit: ', output0);
    console.log('Amount1 to deposit: ', output1);
  }

  function logPrices(RangePool rangePool) public view {
    (uint256 price0, uint256 price1) = rangePool.prices();

    console.log('---------------------------------------');
    console.log('logPrices() Function Call');
    console.log('Price Token 0: ', price0);
    console.log('Price Token 1: ', price1);
    console.log('---------------------------------------');
  }

  function logPricesFromLiquidity(RangePool rangePool) public view {
    (uint256 price0, uint256 price1) = rangePool.pricesFromLiquidity();

    console.log('Price From Liquidity Token 0: ', price0);
    console.log('Price From Liquidity Token 1: ', price1);
  }

  function logOraclePrices(RangePool rangePool, uint32 _seconds) public view {
    (uint256 price0, uint256 price1) = rangePool.oraclePrices(_seconds);

    console.log('Oracle Price Token 0: ', price0);
    console.log('Oracle Price Token 1: ', price1);
  }

  function logLimits(RangePool rangePool) public view {
    console.log('---------------------------------------');
    console.log('logLimits() Function Call');
    console.log('Lower Limit: ', rangePool.lowerLimit());
    console.log('Upper Limit: ', rangePool.upperLimit());
    console.log('---------------------------------------');
  }

  function getWeth(address weth, uint256 amount) public payable {
    require(address(this).balance >= amount, 'Not enough Ether in account');
    IWETH9(weth).deposit{ value: amount }();
  }

  function swap(
    address tokenIn,
    address tokenOut,
    uint24 fee,
    uint256 amountIn
  ) public returns (uint256 amountOut) {
    IUniswapV3Pool pool = IUniswapV3Pool(factory.getPool(tokenIn, tokenOut, fee));
    (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(pool).slot0();

    uint160 limit = pool.token0() == tokenIn
      ? sqrtPriceX96 - sqrtPriceX96 / 10
      : sqrtPriceX96 + sqrtPriceX96 / 10;

    ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
      tokenIn: tokenIn,
      tokenOut: tokenOut,
      fee: fee,
      recipient: address(this),
      deadline: block.timestamp,
      amountIn: amountIn,
      amountOutMinimum: 0,
      sqrtPriceLimitX96: limit
    });

    amountOut = router.exactInputSingle(params);
  }
}
