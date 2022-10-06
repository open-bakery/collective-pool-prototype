// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.8.0;
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

  function setUp() public {}

  function testArbitrum() public {
    address WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // Token0
    address USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8; // Token1
    address GMX = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a;
    uint24 fee = 3000;
    //address pool = 0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443;

    //RangePool rangePool = new RangePool(WETH, USDC, fee, 1000_000000, 2000_000000);

    // CHECK THIS OUT! https://etherscan.io/address/0x00D54F129293b1580C779c8F04b2d8cE370cA69d#code - decodeSqrtPriceX96

    IUniswapV3Pool pool = IUniswapV3Pool(factory.getPool(WETH, GMX, 3000));

    RangePool rangePool = new RangePool(WETH, GMX, fee, 6690000000000000000, 991000000000000000000);

    console.logInt(rangePool.lowerTick());
    console.logInt(rangePool.upperTick());

    logPrices(rangePool);

    // uint256 amountETH = 50 ether;
    //
    // ERC20(WETH).approve(address(rangePool), amountETH);
    // getWeth(WETH, amountETH);
    // uint256 amountOut = rangePool.swap(WETH, amountETH, 50);
    // console.log('Amount out: ', amountOut);
    //
    // uint256 amountUSDC = 1400_000000;
    //
    // ERC20(USDC).approve(address(rangePool), amountUSDC);
    // amountOut = rangePool.swap(USDC, amountUSDC, 50);
    // console.log('Amount out: ', amountOut);

    // uint256 amountETH = 50 ether;
    // ERC20(WETH).approve(address(router), type(uint256).max);
    // getWeth(WETH, amountETH);
    // swap(WETH, USDC, fee, amountETH);
    // uint256 amountOut = rangePool.swap(WETH, amountETH, 50);
    // console.log('Amount out: ', amountOut);
    // uint256 amountUSDC = 1400_000000;
    // uint256 amountWETH = 3_000_000_000_000_000_000;

    // getWeth(WETH, amountWETH);
    // ERC20(WETH).approve(address(rangePool), type(uint256).max);
    // ERC20(USDC).approve(address(rangePool), type(uint256).max);
    // rangePool.addLiquidity(amountWETH, amountUSDC, 100);
    // uint256 balanceLP = rangePool.lpToken().balanceOf(address(this));
    // ERC20(rangePool.lpToken()).approve(address(rangePool), balanceLP);
    // (uint256 amount0Decreased, uint256 amount1Decreased) = rangePool.decreaseLiquidity(
    //   uint128(balanceLP / 2),
    //   100
    // );
    //
    // console.log('----------------------------------');
    // console.log('testArbitrum() Function Call');
    // console.log('amount0Decreased: ', amount0Decreased);
    // console.log('amount1Decreased: ', amount1Decreased);
    // console.log('WETH.balanceOf(address(this))', ERC20(WETH).balanceOf(address(this)));
    // console.log('USDC.balanceOf(address(this))', ERC20(USDC).balanceOf(address(this)));
    // console.log('----------------------------------');
    //
    // rangePool.addLiquidity(amount0Decreased, amount1Decreased, 100);
  }

  function testMainnet() public {
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // Token 0
    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // Token 1
    uint24 fee = 500;
    // address pool = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;

    RangePool rangePool = new RangePool(WETH, USDC, fee, 1000000000000000, 500000000000000);

    // logPrices(rangePool);
    // logOraclePrices(rangePool, 300);
    // logLimits(rangePool);

    // !IMPORTANT! Above and Below Range Limit throw an error.
    //logRatios(rangePool, 1700_000000, 2 ether);

    uint256 amountETH = 50 ether;
    ERC20(WETH).approve(address(router), type(uint256).max);
    getWeth(WETH, amountETH);
    swap(WETH, USDC, fee, amountETH);
    // uint256 amountOut = rangePool.swap(WETH, amountETH, 50);
    // console.log('Amount out: ', amountOut);

    uint256 amountUSDC = 0;
    uint256 amountWETH = 149800000000000000;

    getWeth(WETH, amountWETH);
    ERC20(WETH).approve(address(rangePool), type(uint256).max);
    ERC20(USDC).approve(address(rangePool), type(uint256).max);

    rangePool.addLiquidity(amountUSDC, amountWETH, 1_00);
    uint256 balanceLP = rangePool.lpToken().balanceOf(address(this));
    ERC20(rangePool.lpToken()).approve(address(rangePool), type(uint256).max);
    (uint256 amount0Decreased, uint256 amount1Decreased) = rangePool.decreaseLiquidity(
      uint128(balanceLP / 2),
      100
    );

    console.log('----------------------------------');
    console.log('testMain() Function Call');
    console.log('amount0Decreased: ', amount0Decreased);
    console.log('amount1Decreased: ', amount1Decreased);
    console.log('WETH.balanceOf(address(this))', ERC20(WETH).balanceOf(address(this)));
    console.log('USDC.balanceOf(address(this))', ERC20(USDC).balanceOf(address(this)));
    console.log('----------------------------------');

    rangePool.addLiquidity(amount0Decreased, amount1Decreased, 100);

    // console.log('Amount out: ', amountOut);
  }

  function testAnvil() public view returns (uint256) {}

  function getWeth(address weth, uint256 amount) public payable {
    require(address(this).balance >= amount, 'Not enough Ether in account');
    IWETH9(weth).deposit{ value: amount }();
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

  // function testMint(
  //   address tokenA,
  //   address tokenB,
  //   uint24 fee,
  //   uint256 lowerPrice,
  //   uint256 upperPrice
  // ) external {
  //   uint256 balanceA = ERC20(tokenA).balanceOf(address(this));
  //   uint256 balanceB = ERC20(tokenB).balanceOf(address(this));
  //
  //   (uint256 _tokenId, uint128 liquidity, uint256 _amount0, uint256 _amount1) = mintNewPosition(
  //     tokenA,
  //     tokenB,
  //     fee,
  //     lowerPrice,
  //     upperPrice,
  //     balanceA,
  //     balanceB
  //   );
  //
  //   (uint256 amount0, uint256 amount1) = _getPrincipal(_tokenId);
  //
  //   console.log(amount0);
  //   console.log(amount1);
  // }

  // function mintNewPosition(
  //   address token0,
  //   address token1,
  //   uint24 poolFee,
  //   uint256 lowerPrice,
  //   uint256 upperPrice,
  //   uint256 amount0Out,
  //   uint256 amount1Out
  // )
  //   public
  //   returns (
  //     uint256 tokenId,
  //     uint128 liquidity,
  //     uint256 amount0,
  //     uint256 amount1
  //   )
  // {
  //   require(lowerPrice != upperPrice, 'Uniswap Tests: Liquidity must be provided within a range.');
  //
  //   (int24 tickL, int24 tickU) = _returnRangeInTicks(
  //     address(_getPool(token0, token1, poolFee)),
  //     lowerPrice,
  //     upperPrice
  //   );
  //
  //   token0.safeApprove(address(NFPM), amount0Out);
  //   token1.safeApprove(address(NFPM), amount1Out);
  //
  //   INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
  //     token0: token0,
  //     token1: token1,
  //     fee: poolFee,
  //     tickLower: tickL, //Ticker needs to exist (right spacing) and be initisalized
  //     tickUpper: tickU,
  //     amount0Desired: amount0Out,
  //     amount1Desired: amount1Out,
  //     amount0Min: 0, // slippage check
  //     amount1Min: 0, // slippage check
  //     recipient: address(this),
  //     deadline: block.timestamp
  //   });
  //
  //   (tokenId, liquidity, amount0, amount1) = NFPM.mint(params);
  // }

  // function onERC721Received(
  //   address operator,
  //   address from,
  //   uint256 tokenId,
  //   bytes calldata data
  // ) external override returns (bytes4) {
  //   // get position information
  //   _createDeposit(operator, tokenId);
  //   return this.onERC721Received.selector;
  // }
  //
  // function _createDeposit(address owner, uint256 tokenId) internal {
  //   (, , address token0, address token1, , , , uint128 liquidity, , , , ) = NFPM.positions(tokenId);
  //
  //   // set the owner and data for position
  //   // operator is msg.sender
  //   deposits[tokenId] = Deposit({
  //     owner: owner,
  //     liquidity: liquidity,
  //     token0: token0,
  //     token1: token1
  //   });
  // }
}
