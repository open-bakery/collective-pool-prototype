// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.9.0;
pragma abicoder v2;

import 'forge-std/Test.sol';

import '@uniswap/v3-core/contracts/UniswapV3Factory.sol';
import '@uniswap/v3-core/contracts/UniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/UniswapV3PoolDeployer.sol';

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import '../src/Lens.sol';
import '../src/SimpleStrategies.sol';

import '../src/RangePoolFactory.sol';
import '../src/RangePool.sol';
import '../src/DepositRatioCalculator.sol';
import '../src/logs/Logs.sol';
import './LocalVars.t.sol';
import './Logs.t.sol';
import './libraries/Utils.sol';

contract UnitTest is Test, LocalVars, Logs, LogsTest, IERC721Receiver {
  using PositionValue for INonfungiblePositionManager;
  using stdStorage for StdStorage;
  using SafeMath for uint256;
  using SafeERC20 for ERC20;

  address public uniFactory = vm.envAddress('UNISWAP_V3_FACTORY');
  address public positionManager = vm.envAddress('UNISWAP_V3_NFPM');
  RangePoolFactory public rangePoolFactory;
  SimpleStrategies public simpleStrategies;
  RangePool public rangePool;
  address public tokenA;
  address public tokenB;
  uint24 public fee;
  uint256 public lowerLimitB;
  uint256 public upperLimitB;

  function setUp() public {
    rangePoolFactory = new RangePoolFactory(uniFactory, positionManager, WETH);
    simpleStrategies = new SimpleStrategies();
    tokenA = USDC;
    tokenB = WETH;
    // tokenA = ARB_USDC;
    // tokenB = ARB_WETH;
    fee = 500;
    lowerLimitB = 0.001 ether;
    upperLimitB = 0.0005 ether;
  }

  function testAnvil() public returns (uint256) {}

  function testArbitrum() public {
    uint16 slippage = 100_00;
    initialize(tokenA, tokenB, fee, lowerLimitB, upperLimitB);
    addLiquidity(20_000_000000, 5 ether, slippage);
    increaseLiquidity(4_000_000000, 1 ether, slippage);
    decreaseLiquidity(uint128(ERC20(rangePool.lpToken()).balanceOf(address(this)).div(2)), slippage);
    performSwaps(tokenA, 100_000_000000, tokenB, fee, 10);
    collectFees();
    performSwaps(tokenA, 100_000_000000, tokenB, fee, 10);
    compound(slippage);
    performSwaps(tokenA, 100_000_000000, tokenB, fee, 10);
    stack(tokenA, slippage);
    updateRange(MAIN_USDC, 1200_000000, 1800_000000, slippage);
  }

  function testFullLogs() public {
    initialize(tokenA, tokenB, fee, lowerLimitB, upperLimitB);
    addLiquidity(20_000_000000, 5 ether, 1_00);
    logPrincipal(rangePool);
    performSwaps(tokenA, 100_000_000000, tokenB, fee, 10);
    logUnclaimedFees(rangePool);
    logAveragePrices(rangePool);
    logTokenAmountsAtLimits(rangePool);
    logPrices(rangePool);
    logOraclePrices(rangePool, 60);
    logLimits(rangePool);
  }

  function testMainnet() public {
    uint16 slippage = 1_00;
    initialize(tokenA, tokenB, fee, lowerLimitB, upperLimitB);
    addLiquidity(20_000_000000, 5 ether, slippage);
    increaseLiquidity(4_000_000000, 1 ether, slippage);
    decreaseLiquidity(uint128(ERC20(rangePool.lpToken()).balanceOf(address(this)).div(2)), slippage);
    performSwaps(tokenA, 100_000_000000, tokenB, fee, 10);
    collectFees();
    performSwaps(tokenA, 100_000_000000, tokenB, fee, 10);
    compound(slippage);
    performSwaps(tokenA, 100_000_000000, tokenB, fee, 10);
    stack(tokenA, slippage);
    updateRange(MAIN_USDC, 1200_000000, 1800_000000, slippage);
  }

  function testPoolConstruct() internal {
    initialize(MAIN_WETH, MAIN_USDC, 500, 1000_000000, 2000_000000);
    logLimits(rangePool);
  }

  function initialize(
    address _token0,
    address _token1,
    uint24 _fee,
    uint256 _lowerLimit,
    uint256 _upperLimit
  ) internal {
    rangePool = RangePool(rangePoolFactory.deployRangePool(_token0, _token1, _fee, _lowerLimit, _upperLimit));
    rangePool.toggleStrategy(address(simpleStrategies));
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

    assertTrue(ERC20(rangePool.lpToken()).balanceOf(address(this)) == liquidityAdded);
    assertTrue(liquidityAdded > 0);
  }

  function increaseLiquidity(
    uint256 amount0,
    uint256 amount1,
    uint16 slippage
  ) internal {
    deal(rangePool.pool().token0(), address(this), amount0);
    deal(rangePool.pool().token1(), address(this), amount1);

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
    assertTrue(ERC20(rangePool.pool().token0()).balanceOf(address(this)) == ibToken0.add(amountDecreased0));
    assertTrue(ERC20(rangePool.pool().token1()).balanceOf(address(this)) == ibToken1.add(amountDecreased1));
  }

  function collectFees() internal {
    (, uint256 ibToken0, uint256 ibToken1) = intialBalances();
    (uint256 amountCollected0, uint256 amountCollected1) = rangePool.collectFees();

    logr(
      'collectFees()',
      ['amountCollected0', 'amountCollected1', '0', '0', '0', '0'],
      [uint256(amountCollected0), amountCollected1, 0, 0, 0, 0]
    );

    assertTrue(ERC20(rangePool.pool().token0()).balanceOf(address(this)) == ibToken0.add(amountCollected0));
    assertTrue(ERC20(rangePool.pool().token1()).balanceOf(address(this)) == ibToken1.add(amountCollected1));
  }

  function compound(uint16 slippage) internal {
    (uint256 ibTokenLP, , ) = intialBalances();
    (uint128 addedLiquidity, uint256 amountCompounded0, uint256 amountCompounded1) = simpleStrategies.compound(
      rangePool,
      slippage
    );

    logr(
      'compound()',
      ['addedLiquidity', 'amountCompounded0', 'amountCompounded1', '0', '0', '0'],
      [uint256(addedLiquidity), amountCompounded0, amountCompounded1, 0, 0, 0]
    );

    assertTrue(ERC20(rangePool.lpToken()).balanceOf(address(this)) == ibTokenLP.add(addedLiquidity));
  }

  function stack(address token, uint16 slippage) internal {
    (, uint256 ibToken0, uint256 ibToken1) = intialBalances();
    uint256 initialBalance = (token == rangePool.pool().token0()) ? ibToken0 : ibToken1;
    uint256 amount = simpleStrategies.stack(rangePool, token, slippage);

    logr('stack()', ['amount', '0', '0', '0', '0', '0'], [uint256(amount), 0, 0, 0, 0, 0]);

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

    uint256 newLowerLimit = lens.lowerLimit(rangePool);
    uint256 newUpperLimit = lens.upperLimit(rangePool);

    logr(
      'updateRange()',
      ['addedLiquidity', 'addedAmount0', 'addedAmount1', 'newLowerLimit', 'newUpperLimit', '0'],
      [uint256(addedLiquidity), addedAmount0, addedAmount1, newLowerLimit, newUpperLimit, 0]
    );
  }

  function intialBalances()
    internal
    view
    returns (
      uint256 amountLP,
      uint256 amount0,
      uint256 amount1
    )
  {
    amountLP = ERC20(rangePool.lpToken()).balanceOf(address(this));
    amount0 = ERC20(rangePool.pool().token0()).balanceOf(address(this));
    amount1 = ERC20(rangePool.pool().token1()).balanceOf(address(this));
  }

  function performSwaps(
    address _tokenA,
    uint256 _amountA,
    address _tokenB,
    uint24 _fee,
    uint8 _swaps
  ) internal {
    ERC20(_tokenA).approve(address(router), type(uint256).max);
    ERC20(_tokenB).approve(address(router), type(uint256).max);
    deal(address(_tokenA), address(this), _amountA);
    uint256 receivedA;
    uint256 receivedB;

    receivedB = swap(_tokenA, _tokenB, _fee, _amountA);

    for (uint8 i = 0; i < _swaps; i++) {
      receivedA = swap(_tokenB, _tokenA, _fee, receivedB);
      receivedB = swap(_tokenA, _tokenB, _fee, receivedA);
    }
  }

  function swap(
    address tokenIn,
    address tokenOut,
    uint24 _fee,
    uint256 amountIn
  ) internal returns (uint256 amountOut) {
    IUniswapV3Pool pool = IUniswapV3Pool(factory.getPool(tokenIn, tokenOut, _fee));
    (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(pool).slot0();

    uint160 limit = pool.token0() == tokenIn ? sqrtPriceX96 - sqrtPriceX96 / 10 : sqrtPriceX96 + sqrtPriceX96 / 10;

    ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
      tokenIn: tokenIn,
      tokenOut: tokenOut,
      fee: _fee,
      recipient: address(this),
      deadline: block.timestamp,
      amountIn: amountIn,
      amountOutMinimum: 0,
      sqrtPriceLimitX96: limit
    });

    amountOut = router.exactInputSingle(params);
  }

  function predictAddress(
    string memory salt,
    address _deployer,
    address _tokenA,
    address _tokenB,
    uint24 _fee,
    uint256 _lowerLimitInTokenB,
    uint256 _upperLimitInTokenB
  ) internal pure returns (address) {
    address predictedAddress = address(
      uint160(
        uint256(
          keccak256(
            abi.encodePacked(
              bytes1(0xff),
              address(_deployer),
              keccak256(abi.encode(salt)),
              keccak256(
                abi.encodePacked(
                  type(RangePool).creationCode,
                  abi.encode(_tokenA, _tokenB, _fee, _lowerLimitInTokenB, _upperLimitInTokenB)
                )
              )
            )
          )
        )
      )
    );
    return predictedAddress;
  }

  function onERC721Received(
    address operator,
    address from,
    uint256 id,
    bytes calldata data
  ) external view override returns (bytes4) {
    operator;
    from;
    id;
    data;

    logr('onERC721Received()', ['0', '0', '0', '0', '0', '0'], [uint256(0), 0, 0, 0, 0, 0]);

    return this.onERC721Received.selector;
  }
}
