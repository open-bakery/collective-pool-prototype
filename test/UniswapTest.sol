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

contract UniswapTest is Test {
  using PositionValue for NonfungiblePositionManager;
  using TransferHelper for address;

  IUniswapV3Factory factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
  NonfungiblePositionManager NFPM =
    NonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
  ISwapRouter router = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

  struct Deposit {
    address owner;
    uint128 liquidity;
    address token0;
    address token1;
  }

  mapping(uint256 => Deposit) deposits;

  function setUp() public {
    // CHECK THIS OUT! https://etherscan.io/address/0x00D54F129293b1580C779c8F04b2d8cE370cA69d#code - decodeSqrtPriceX96
  }

  function testArbitrum() public {
    // testArbiUSD_ETH();
    testArbiETH_GMX();
  }

  function testMainnet() public {
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // Token 0
    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // Token 1
    uint24 fee = 500;
    // address pool = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;

    RangePool rangePool = new RangePool(WETH, USDC, fee, 499000000000000, 999700000000000);

    // logPrices(rangePool);
    // logOraclePrices(rangePool, 300);
    // logLimits(rangePool);

    // !IMPORTANT! Above and Below Range Limit throw an error.
    //logRatios(rangePool, 1700_000000, 2 ether);

    uint256 amountETH = 50 ether;
    getWeth(WETH, amountETH);

    ERC20(WETH).approve(address(router), type(uint256).max);
    ERC20(WETH).approve(address(rangePool), type(uint256).max);
    ERC20(USDC).approve(address(rangePool), type(uint256).max);

    swap(WETH, USDC, fee, amountETH / 2);

    uint256 amountUSDC = 12780_000000;
    uint256 amountWETH = 11470000000000000000;

    rangePool.addLiquidity(amountUSDC, amountWETH, 1_00);

    logTokenAmountsAtLimits(rangePool);

    ERC20(rangePool.lpToken()).approve(address(rangePool), type(uint256).max);

    (uint256 amount0Decreased, uint256 amount1Decreased) = rangePool.decreaseLiquidity(
      uint128(ERC20(rangePool.lpToken()).balanceOf(address(this)) / 2),
      1_00
    );

    console.log('----------------------------------');
    console.log('testMain() Function Call');
    console.log('amount0Decreased: ', amount0Decreased);
    console.log('amount1Decreased: ', amount1Decreased);
    console.log('WETH.balanceOf(address(this))', ERC20(WETH).balanceOf(address(this)));
    console.log('USDC.balanceOf(address(this))', ERC20(USDC).balanceOf(address(this)));
    console.log('----------------------------------');

    rangePool.addLiquidity(amount0Decreased, amount1Decreased, 100);
  }

  function testAnvil() public returns (uint256) {
    PoolFactory pool = new PoolFactory();
    uint256 a = type(uint256).max;
    uint256 b = type(uint256).max;
    pool.add(a, b);
  }

  function testArbiUSD_ETH() public {
    address WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // Token0
    address USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8; // Token1
    uint24 fee = 500;
    //address pool = 0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443;

    RangePool rangePool = new RangePool(WETH, USDC, fee, 1000_000000, 2000_000000);

    uint256 amountETH = 50 ether;
    getWeth(WETH, amountETH);

    ERC20(WETH).approve(address(router), type(uint256).max);
    ERC20(WETH).approve(address(rangePool), type(uint256).max);
    ERC20(USDC).approve(address(rangePool), type(uint256).max);

    swap(WETH, USDC, fee, amountETH / 2);

    uint256 amountWETH = 3_000_000_000_000_000_000;
    uint256 amountUSDC = 1400_000000;

    rangePool.addLiquidity(amountWETH, amountUSDC, 100);

    logTokenAmountsAtLimits(rangePool);
  }

  function testArbiETH_GMX() public {
    address WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // Token0
    address GMX = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a; // Token1
    uint24 fee = 3000;

    IUniswapV3Pool pool = IUniswapV3Pool(factory.getPool(WETH, GMX, fee));

    uint256 tokenId = vm.envUint('TOKENID');
    (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
    (uint256 amount0, uint256 amount1) = NFPM.principal(tokenId, sqrtPriceX96);

    RangePool rangePool = new RangePool(WETH, GMX, fee, 2500000000000000000, 125000000000000000000);

    uint256 amountETH = 50 ether;
    getWeth(WETH, amountETH);

    ERC20(WETH).approve(address(router), type(uint256).max);
    ERC20(WETH).approve(address(rangePool), type(uint256).max);
    ERC20(GMX).approve(address(rangePool), type(uint256).max);

    swap(WETH, GMX, fee, amountETH / 2);

    rangePool.addLiquidity(amount0, amount1, 1_00);

    logTokenAmountsAtLimits(rangePool);
  }

  function getWeth(address weth, uint256 amount) public payable {
    require(address(this).balance >= amount, 'Not enough Ether in account');
    IWETH9(weth).deposit{ value: amount }();
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

    console.log('Price Token 0: ', price0);
    console.log('Price Token 1: ', price1);
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
    console.log('Lower Limit: ', rangePool.lowerLimit());
    console.log('Upper Limit: ', rangePool.upperLimit());
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
