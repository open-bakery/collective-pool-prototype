// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.9.0;
pragma abicoder v2;

import 'forge-std/Test.sol';

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import '../src/RangePool.sol';
import '../src/DepositRatioCalculator.sol';
import '../src/logs/Logs.sol';
import './LocalVars.t.sol';
import './Logs.t.sol';

contract UnitTest is Test, LocalVars, Logs, LogsTest, IERC721Receiver {
  using PositionValue for NonfungiblePositionManager;
  using TransferHelper for address;
  using stdStorage for StdStorage;
  using SafeMath for uint256;

  RangePool public rangePool;

  function setUp() public {}

  function testArbitrum() public {
    // testCases(0, ARB_WETH, 5 ether, ARB_USDC, 20000_000000, 500);
    // fullLogs(ARB_WETH, 5 ether, ARB_USDC, 2000_000000, 500);
  }

  function testMainnet() public {
    initialize(MAIN_USDC, MAIN_WETH, 500, 0.001 ether, 0.0005 ether);
    addLiquidity(20_000_000000, 5 ether, 1_00);
    increaseLiquidity(4_000_000000, 1 ether, 1_00);
    decreaseLiquidity(uint128(ERC20(rangePool.lpToken()).balanceOf(address(this)).div(2)), 1_00);
    // DepositRatioCalculator drc = new DepositRatioCalculator();
    // drc.calculateDepositRatio(MAIN_WBTC, MAIN_WETH, 500, 3_0000_0000, 1 ether, 5 ether, 30 ether);
    // testCases(0, MAIN_WETH, 100 ether, MAIN_USDC, 20_000_000000, 500);
    // testPoolConstruct(MAIN_WETH, MAIN_USDC, 500, 1000_000000, 2000_000000);
    // testPoolConstruct(MAIN_USDC, MAIN_WETH, 500, 1000000000000000, 500000000000000);
    // testSwapFromDCA(MAIN_APE, MAIN_WETH, 3000, 64_000 ether, 5_00);
  }

  function testAnvil() public returns (uint256) {}

  function initialize(
    address token0,
    address token1,
    uint24 fee,
    uint256 lowerLimit,
    uint256 upperLimit
  ) public {
    rangePool = new RangePool(token0, token1, fee, lowerLimit, upperLimit);
    ERC20(token0).approve(address(rangePool), type(uint256).max);
    ERC20(token1).approve(address(rangePool), type(uint256).max);
  }

  function testPoolConstruct(
    address tokenA,
    address tokenB,
    uint24 fee,
    uint256 lowerLimitInTokenB,
    uint256 upperLimitInTokenB
  ) public returns (RangePool rangePool) {
    rangePool = new RangePool(tokenA, tokenB, fee, lowerLimitInTokenB, upperLimitInTokenB);
    logLimits(rangePool);
    console.log(rangePool.token0());
  }

  function addLiquidity(
    uint256 amount0,
    uint256 amount1,
    uint16 slippage
  ) public {
    deal(rangePool.token0(), address(this), amount0);
    deal(rangePool.token1(), address(this), amount1);

    (uint128 liquidityAdded, uint256 amount0Added, uint256 amount1Added) = rangePool.addLiquidity(
      amount0,
      amount1,
      slippage
    );

    logr(
      'testAddLiquidity()',
      ['liquidityAdded', 'amount0Added', 'amount1Added', '0', '0', '0'],
      [uint256(liquidityAdded), amount0Added, amount1Added, 0, 0, 0]
    );

    assertTrue(ERC20(rangePool.lpToken()).balanceOf(address(this)) == liquidityAdded);
    assertTrue(liquidityAdded > 0);
  }

  function increaseLiquidity(
    uint256 amount0,
    uint256 amount1,
    uint16 slippage
  ) public {
    deal(rangePool.token0(), address(this), amount0);
    deal(rangePool.token1(), address(this), amount1);

    uint256 initialBalancelpToken = ERC20(rangePool.lpToken()).balanceOf(address(this));

    (uint128 liquidityAdded, uint256 amount0Added, uint256 amount1Added) = rangePool.addLiquidity(
      amount0,
      amount1,
      slippage
    );

    logr(
      'testIncreaseLiquidity()',
      ['liquidityAdded', 'amount0Added', 'amount1Added', '0', '0', '0'],
      [uint256(liquidityAdded), amount0Added, amount1Added, 0, 0, 0]
    );

    assertTrue(
      ERC20(rangePool.lpToken()).balanceOf(address(this)) == uint256(liquidityAdded).add(initialBalancelpToken)
    );
    assertTrue(liquidityAdded > 0);
  }

  function decreaseLiquidity(uint128 liquidity, uint16 slippage) public {
    uint256 initialBalancelpToken = ERC20(rangePool.lpToken()).balanceOf(address(this));
    uint256 initialBalanceToken0 = ERC20(rangePool.token0()).balanceOf(address(this));
    uint256 initialBalanceToken1 = ERC20(rangePool.token1()).balanceOf(address(this));

    (uint256 amountDecreased0, uint256 amountDecreased1) = rangePool.decreaseLiquidity(liquidity, slippage);

    logr(
      'decreaseLiquidity()',
      ['amountDecreased0', 'amountDecreased1', '0', '0', '0', '0'],
      [uint256(amountDecreased0), amountDecreased1, 0, 0, 0, 0]
    );

    assertTrue(ERC20(rangePool.lpToken()).balanceOf(address(this)) == initialBalancelpToken.sub(uint256(liquidity)));
    assertTrue(ERC20(rangePool.token0()).balanceOf(address(this)) == initialBalanceToken0.add(amountDecreased0));
    assertTrue(ERC20(rangePool.token1()).balanceOf(address(this)) == initialBalanceToken1.add(amountDecreased1));
  }

  function claimFees() public {}

  //
  // function testCases(
  //   uint8 test,
  //   address tokenA,
  //   uint256 amountA,
  //   address tokenB,
  //   uint256 amountB,
  //   uint24 fee
  // ) public {
  //   (RangePool rangePool, uint256 amount0, uint256 amount1) = initialize(
  //     tokenA,
  //     amountA,
  //     tokenB,
  //     amountB,
  //     fee
  //   );
  //
  //   if (test == 0) testLiquidityProvisionAndNFTClaim(rangePool, amount0, amount1);
  //   if (test == 1) testAutoCompound(rangePool, amount0 * 100, amount1 * 100);
  // }
  //
  // function testSwapFromDCA(
  //   address tokenIn,
  //   address tokenOut,
  //   uint24 fee,
  //   uint256 amountIn,
  //   uint16 slippage
  // ) public {
  //   SDCA sdca = new SDCA();
  //   ERC20(tokenIn).approve(address(sdca), type(uint256).max);
  //   deal(tokenIn, address(this), amountIn);
  //   uint256 amountOut = sdca.swap(tokenIn, tokenOut, fee, amountIn, slippage);
  //   assertTrue(ERC20(tokenOut).balanceOf(address(this)) == amountOut);
  // }
  //
  // function testAutoCompound(
  //   RangePool rangePool,
  //   uint256 amount0,
  //   uint256 amount1
  // ) public {
  //   uint16 slippage = 20_00;
  //   uint8 multiplier = 10;
  //
  //   deal(rangePool.token0(), address(this), amount0);
  //   deal(rangePool.token1(), address(this), amount1);
  //
  //   rangePool.addLiquidity(amount0, amount1, slippage);
  //
  //   deal(rangePool.token0(), address(this), amount0 * multiplier);
  //
  //   performSwaps(rangePool.token0(), amount0 * multiplier, rangePool.token1(), 500);
  //   (, uint256 compounded0, uint256 compounded1) = rangePool.compound(3_00);
  //   console.log('compounded0: ', compounded0);
  //   console.log('compounded1: ', compounded1);
  //
  //   (uint256 feeA, uint256 feeB) = NFPM.fees(rangePool.tokenId());
  //   console.log('feeA: ', feeA);
  //   console.log('feeA: ', feeB);
  //
  //   console.log('LP Balance RangePool: ', ERC20(rangePool.lpToken()).balanceOf(address(rangePool)));
  // }
  //
  // function testLiquidityProvisionAndNFTClaim(
  //   RangePool rangePool,
  //   uint256 amount0,
  //   uint256 amount1
  // ) public {
  //   uint16 slippage = 5_00;
  //
  //   deal(rangePool.token0(), address(this), amount0);
  //   deal(rangePool.token1(), address(this), amount1);
  //
  //   rangePool.addLiquidity(amount0, amount1, slippage);
  //
  //   ERC20(rangePool.lpToken()).approve(address(rangePool), type(uint256).max);
  //
  //   (uint256 amount0Decreased, uint256 amount1Decreased) = rangePool.decreaseLiquidity(
  //     uint128(ERC20(rangePool.lpToken()).balanceOf(address(this)) / 2),
  //     slippage
  //   );
  //
  //   rangePool.addLiquidity(amount0Decreased, amount1Decreased, slippage);
  //
  //   rangePool.claimNFT();
  //   assertTrue(NFPM.ownerOf(rangePool.tokenId()) == address(this));
  //   assertTrue(ERC20(rangePool.lpToken()).balanceOf(address(this)) == 0);
  // }
  //
  // function logCalculateDepositRatio(
  //   RangePool rangePool,
  //   uint256 amount0,
  //   uint256 amount1
  // ) public {
  //   uint16 slippage = 5_00;
  //
  //   deal(rangePool.token0(), address(this), amount0);
  //   deal(rangePool.token1(), address(this), amount1);
  //
  //   (uint256 amountRatioed0, uint256 amountRatioed1) = rangePool.calculateDepositRatio(
  //     amount0 / 2,
  //     amount1 / 2
  //   );
  //
  //   logr(
  //     'logCalculateDepositRatio()',
  //     ['amountRatioed0', 'amountRatioed1', '0', '0', '0', '0'],
  //     [uint256(amountRatioed0), amountRatioed1, 0, 0, 0, 0]
  //   );
  // }
  //
  function performSwaps(
    address tokenA,
    uint256 amount0,
    address tokenB,
    uint24 fee
  ) internal {
    ERC20(tokenA).approve(address(router), type(uint256).max);
    ERC20(tokenB).approve(address(router), type(uint256).max);
    deal(address(tokenA), address(this), amount0);
    uint256 receivedA;
    uint256 receivedB;

    receivedB = swap(tokenA, tokenB, fee, amount0);
    receivedA = swap(tokenB, tokenA, fee, receivedB);
    receivedB = swap(tokenA, tokenB, fee, receivedA);
    receivedA = swap(tokenB, tokenA, fee, receivedB);
    receivedB = swap(tokenA, tokenB, fee, receivedA);
    receivedA = swap(tokenB, tokenA, fee, receivedB);
    receivedB = swap(tokenA, tokenB, fee, receivedA);
    receivedA = swap(tokenB, tokenA, fee, receivedB);
    receivedB = swap(tokenA, tokenB, fee, receivedA);
    receivedA = swap(tokenB, tokenA, fee, receivedB);
    receivedB = swap(tokenA, tokenB, fee, receivedA);
    receivedA = swap(tokenB, tokenA, fee, receivedB);
    receivedB = swap(tokenA, tokenB, fee, receivedA);
    receivedA = swap(tokenB, tokenA, fee, receivedB);
  }

  function swap(
    address tokenIn,
    address tokenOut,
    uint24 fee,
    uint256 amountIn
  ) public returns (uint256 amountOut) {
    IUniswapV3Pool pool = IUniswapV3Pool(factory.getPool(tokenIn, tokenOut, fee));
    (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(pool).slot0();

    uint160 limit = pool.token0() == tokenIn ? sqrtPriceX96 - sqrtPriceX96 / 10 : sqrtPriceX96 + sqrtPriceX96 / 10;

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

  function onERC721Received(
    address operator,
    address from,
    uint256 id,
    bytes calldata data
  ) external override returns (bytes4) {
    operator;
    from;
    id;
    data;

    console.log('-----------------------------');
    console.log('onERC721Received() Function Call');
    console.log('-----------------------------');

    return this.onERC721Received.selector;
  }
}
