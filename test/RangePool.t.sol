// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.9.0;
pragma abicoder v2;

import '../src/libraries/Helper.sol';

import '../src/interfaces/IRangePool.sol';

import '../src/utility/TestHelpers.sol';
import './Logs.t.sol';

contract RangePoolTest is LogsTest {
  using PositionValue for INonfungiblePositionManager;
  using SafeMath for uint256;
  using SafeMath for uint128;
  using SafeERC20 for ERC20;

  IUniswapV3Pool deployedPool;

  address public tokenA;
  address public tokenB;
  uint24 public fee;
  uint32 public oracleSeconds;
  uint256 public lowerLimitB;
  uint256 public upperLimitB;

  function setUp() public {
    lens = new Lens();

    deployAndDistributeTokens();
    deployUniswapBase(tokens.weth);
    initPoolProps();
    deployedPool = createUniswapPool(poolProps[1], 10_000, 10_500_000, 1500);
    tokenA = poolProps[1].tokenA; // weth
    tokenB = poolProps[1].tokenB; // dai
    fee = poolProps[1].fee;
    oracleSeconds = 60;
    lowerLimitB = simpleAmount(1_000, tokenB);
    upperLimitB = simpleAmount(2_000, tokenB);
  }

  function testRangePool() public {
    uint16 slippage = 10_00;
    initialize(tokenA, tokenB, fee, oracleSeconds, lowerLimitB, upperLimitB);
    // Performs swap to record price to Oracle.
    performSwaps(tokenA, simpleAmount(100, tokenA), tokenB, fee, 10);
    addLiquidity(simpleAmount(20_000, tokenB), 5 ether, slippage);
    increaseLiquidity(simpleAmount(4_000, tokenB), 0, slippage);
    removeLiquidity(uint128(_getLiquidity(rangePool).div(100)), slippage);
    performSwaps(tokenA, simpleAmount(10_000, tokenA), tokenB, fee, 10);
    logPrices(rangePool);
    collectFees();
    performSwaps(tokenA, simpleAmount(10_000, tokenA), tokenB, fee, 10);
    updateRange(tokenB, simpleAmount(800, tokenB), simpleAmount(1_500, tokenB), slippage);
  }

  function testPoolConstruct() public {
    uint256 lowerLimit = 0.001 ether;
    uint256 upperLimit = 0.0005 ether;
    initialize(tokenB, tokenA, fee, 60, lowerLimit, upperLimit);
    (int24 lowerTick, int24 upperTick) = Helper.validateAndConvertLimits(
      rangePool.pool(),
      tokenA,
      lowerLimit,
      upperLimit
    );

    assertTrue(rangePool.lowerTick() == lowerTick);
    assertTrue(rangePool.upperTick() == upperTick);
  }

  function initialize(
    address _token0,
    address _token1,
    uint24 _fee,
    uint32 _oracleSeconds,
    uint256 _lowerLimit,
    uint256 _upperLimit
  ) internal {
    IRangePool.DeploymentParameters memory params = IRangePool.DeploymentParameters({
      uniswapFactory: address(uniswapFactory),
      uniswapRouter: address(uniswapRouter),
      positionManager: address(positionManager),
      tokenA: _token0,
      tokenB: _token1,
      fee: _fee,
      oracleSeconds: _oracleSeconds,
      lowerLimitInTokenB: _lowerLimit,
      upperLimitInTokenB: _upperLimit
    });

    rangePool = new RangePool(params);

    ERC20(_token0).approve(address(rangePool), type(uint256).max);
    ERC20(_token1).approve(address(rangePool), type(uint256).max);
  }

  function addLiquidity(
    uint256 amount0,
    uint256 amount1,
    uint16 slippage
  ) internal {
    deal(rangePool.pool().token0(), address(this), amount0);
    deal(rangePool.pool().token1(), address(this), amount1);

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

    assertTrue(Helper.positionLiquidity(rangePool.positionManager(), rangePool.tokenId()) == liquidityAdded);
    assertTrue(liquidityAdded > 0);
  }

  function increaseLiquidity(
    uint256 amount0,
    uint256 amount1,
    uint16 slippage
  ) internal {
    deal(rangePool.pool().token0(), address(this), amount0);
    deal(rangePool.pool().token1(), address(this), amount1);

    (uint256 iLiquidity, uint256 ibToken0, uint256 ibToken1) = _intialBalances();

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
      Helper.positionLiquidity(rangePool.positionManager(), rangePool.tokenId()) ==
        uint256(liquidityAdded).add(iLiquidity)
    );
    assertTrue(liquidityAdded > 0);
  }

  function removeLiquidity(uint128 liquidity, uint16 slippage) internal {
    uint128 initialLiquidity = Helper.positionLiquidity(rangePool.positionManager(), rangePool.tokenId());

    (uint256 ibTokenLP, uint256 ibToken0, uint256 ibToken1) = _intialBalances();

    (uint256 amountDecreased0, uint256 amountDecreased1) = rangePool.removeLiquidity(liquidity, slippage);

    logr(
      'decreaseLiquidity()',
      ['amountDecreased0', 'amountDecreased1', '0', '0', '0', '0'],
      [uint256(amountDecreased0), amountDecreased1, 0, 0, 0, 0]
    );

    assertTrue(_getLiquidity(rangePool) == initialLiquidity.sub(uint256(liquidity)));
    assertTrue(ERC20(rangePool.pool().token0()).balanceOf(address(this)) == ibToken0.add(amountDecreased0));
    assertTrue(ERC20(rangePool.pool().token1()).balanceOf(address(this)) == ibToken1.add(amountDecreased1));
  }

  function collectFees() internal {
    (uint256 ibTokenLP, uint256 ibToken0, uint256 ibToken1) = _intialBalances();
    (address token0, address token1, uint256 amountCollected0, uint256 amountCollected1) = rangePool.collectFees();

    logr(
      'collectFees()',
      ['amountCollected0', 'amountCollected1', '0', '0', '0', '0'],
      [uint256(amountCollected0), amountCollected1, 0, 0, 0, 0]
    );

    assertTrue(ERC20(rangePool.pool().token0()).balanceOf(address(this)) == ibToken0.add(amountCollected0));
    assertTrue(ERC20(rangePool.pool().token1()).balanceOf(address(this)) == ibToken1.add(amountCollected1));
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

    uint256 newLowerLimit = lens.lowerLimit(rangePool);
    uint256 newUpperLimit = lens.upperLimit(rangePool);

    logr(
      'updateRange()',
      ['addedLiquidity', 'addedAmount0', 'addedAmount1', 'newLowerLimit', 'newUpperLimit', '0'],
      [uint256(addedLiquidity), addedAmount0, addedAmount1, newLowerLimit, newUpperLimit, 0]
    );
  }

  function _getLiquidity(RangePool _rp) internal view returns (uint128 _liquidity) {
    _liquidity = Helper.positionLiquidity(rangePool.positionManager(), rangePool.tokenId());
  }

  function _intialBalances()
    internal
    view
    returns (
      uint256 _liquidity,
      uint256 _amount0,
      uint256 _amount1
    )
  {
    _liquidity = _getLiquidity(rangePool);
    _amount0 = ERC20(rangePool.pool().token0()).balanceOf(address(this));
    _amount1 = ERC20(rangePool.pool().token1()).balanceOf(address(this));
  }
}
