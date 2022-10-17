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
  using PositionValue for INonfungiblePositionManager;
  using stdStorage for StdStorage;
  using SafeMath for uint256;
  using SafeERC20 for ERC20;

  RangePool public rangePool;

  function setUp() public {}

  function testAnvil() public returns (uint256) {}

  function testArbitrum() public {
    // testCases(0, ARB_WETH, 5 ether, ARB_USDC, 20000_000000, 500);
    // fullLogs(ARB_WETH, 5 ether, ARB_USDC, 2000_000000, 500);
  }

  function testMainnet() public {
    address tokenA = MAIN_USDC;
    address tokenB = MAIN_WETH;
    uint24 fee = 500;
    uint256 lowerLimitB = 0.001 ether;
    uint256 upperLimitB = 0.0005 ether;

    initialize(tokenA, tokenB, fee, lowerLimitB, upperLimitB);
    addLiquidity(20_000_000000, 5 ether, 1_00);
    increaseLiquidity(4_000_000000, 1 ether, 1_00);
    decreaseLiquidity(uint128(ERC20(rangePool.lpToken()).balanceOf(address(this)).div(2)), 1_00);
    performSwaps(tokenA, 100_000_000000, tokenB, fee);
    collectFees();
    performSwaps(tokenA, 100_000_000000, tokenB, fee);
    compound(1_00);
    performSwaps(tokenA, 100_000_000000, tokenB, fee);
    dca(tokenA, 1_00);
    updateRange(MAIN_USDC, 1200_000000, 1800_000000, 1_00);
  }

  function testPoolConstruct() internal {
    rangePool = new RangePool(MAIN_USDC, MAIN_WETH, 500, 0.01 ether, 0.005 ether);
    logLimits(rangePool);
  }

  function initialize(
    address token0,
    address token1,
    uint24 fee,
    uint256 lowerLimit,
    uint256 upperLimit
  ) internal {
    rangePool = new RangePool(token0, token1, fee, lowerLimit, upperLimit);
    ERC20(token0).approve(address(rangePool), type(uint256).max);
    ERC20(token1).approve(address(rangePool), type(uint256).max);
  }

  function addLiquidity(
    uint256 amount0,
    uint256 amount1,
    uint16 slippage
  ) internal {
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
  ) internal {
    deal(rangePool.token0(), address(this), amount0);
    deal(rangePool.token1(), address(this), amount1);

    (uint256 ibLPTokenLP, , ) = intialBalances();

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

    assertTrue(ERC20(rangePool.lpToken()).balanceOf(address(this)) == uint256(liquidityAdded).add(ibLPTokenLP));
    assertTrue(liquidityAdded > 0);
  }

  function decreaseLiquidity(uint128 liquidity, uint16 slippage) internal {
    (uint256 ibTokenLP, uint256 ibToken0, uint256 ibToken1) = intialBalances();

    (uint256 amountDecreased0, uint256 amountDecreased1) = rangePool.decreaseLiquidity(liquidity, slippage);

    logr(
      'decreaseLiquidity()',
      ['amountDecreased0', 'amountDecreased1', '0', '0', '0', '0'],
      [uint256(amountDecreased0), amountDecreased1, 0, 0, 0, 0]
    );

    assertTrue(ERC20(rangePool.lpToken()).balanceOf(address(this)) == ibTokenLP.sub(uint256(liquidity)));
    assertTrue(ERC20(rangePool.token0()).balanceOf(address(this)) == ibToken0.add(amountDecreased0));
    assertTrue(ERC20(rangePool.token1()).balanceOf(address(this)) == ibToken1.add(amountDecreased1));
  }

  function collectFees() internal {
    (, uint256 ibToken0, uint256 ibToken1) = intialBalances();
    (uint256 amountCollected0, uint256 amountCollected1) = rangePool.collectFees();

    logr(
      'collectFees()',
      ['amountCollected0', 'amountCollected1', '0', '0', '0', '0'],
      [uint256(amountCollected0), amountCollected1, 0, 0, 0, 0]
    );

    assertTrue(ERC20(rangePool.token0()).balanceOf(address(this)) == ibToken0.add(amountCollected0));
    assertTrue(ERC20(rangePool.token1()).balanceOf(address(this)) == ibToken1.add(amountCollected1));
  }

  function compound(uint16 slippage) internal {
    (uint256 ibTokenLP, , ) = intialBalances();
    (uint128 addedLiquidity, uint256 amountCompounded0, uint256 amountCompounded1) = rangePool.compound(slippage);

    logr(
      'compound()',
      ['addedLiquidity', 'amountCompounded0', 'amountCompounded1', '0', '0', '0'],
      [uint256(addedLiquidity), amountCompounded0, amountCompounded1, 0, 0, 0]
    );

    assertTrue(ERC20(rangePool.lpToken()).balanceOf(address(this)) == ibTokenLP.add(addedLiquidity));
  }

  function dca(address token, uint16 slippage) internal {
    (, uint256 ibToken0, uint256 ibToken1) = intialBalances();
    uint256 initialBalance = (token == rangePool.token0()) ? ibToken0 : ibToken1;
    uint256 amount = rangePool.dca(token, slippage);

    logr('dca()', ['amount', '0', '0', '0', '0', '0'], [uint256(amount), 0, 0, 0, 0, 0]);

    assertTrue(amount > 0);
    assertTrue(ERC20(token).balanceOf(address(this)) == initialBalance.add(amount));
  }

  function updateRange(
    address token,
    uint256 lowerLimit,
    uint256 upperLimit,
    uint16 slippage
  ) internal {
    (uint128 addedLiquidity, uint256 addedAmount0, uint256 addedAmount1) = rangePool.updateRange(
      token,
      lowerLimit,
      upperLimit,
      slippage
    );

    uint256 newLowerLimit = rangePool.lowerLimit();
    uint256 newUpperLimit = rangePool.upperLimit();

    logr(
      'updateRange()',
      ['addedLiquidity', 'addedAmount0', 'addedAmount1', 'newLowerLimit', 'newUpperLimit', '0'],
      [uint256(addedLiquidity), addedAmount0, addedAmount1, newLowerLimit, newUpperLimit, 0]
    );
  }

  function intialBalances()
    internal
    returns (
      uint256 amountLP,
      uint256 amount0,
      uint256 amount1
    )
  {
    amountLP = ERC20(rangePool.lpToken()).balanceOf(address(this));
    amount0 = ERC20(rangePool.token0()).balanceOf(address(this));
    amount1 = ERC20(rangePool.token1()).balanceOf(address(this));
  }

  function performSwaps(
    address tokenA,
    uint256 amountA,
    address tokenB,
    uint24 fee
  ) internal {
    ERC20(tokenA).approve(address(router), type(uint256).max);
    ERC20(tokenB).approve(address(router), type(uint256).max);
    deal(address(tokenA), address(this), amountA);
    uint256 receivedA;
    uint256 receivedB;

    receivedB = swap(tokenA, tokenB, fee, amountA);
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
  ) internal returns (uint256 amountOut) {
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

    logr('onERC721Received()', ['0', '0', '0', '0', '0', '0'], [uint256(0), 0, 0, 0, 0, 0]);

    return this.onERC721Received.selector;
  }
}
