// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.8.0;
pragma abicoder v2;

import '@uniswap/v3-periphery/contracts/libraries/PositionValue.sol';
import '../src/utility/TestHelpers.sol';
import '../src/SimpleStrategies.sol';

contract SimpleStrategiesTest is TestHelpers {
  using PositionValue for INonfungiblePositionManager;
  IUniswapV3Pool deployedPool;

  address public tokenA;
  address public tokenB;
  uint24 public fee;
  uint32 public oracleSeconds;
  uint256 public lowerLimitB;
  uint256 public upperLimitB;

  function setUp() public {
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
    deployOurBase();
    rangePoolManager = new RangePoolManager(address(rangePoolFactory));
    // Performs swap to record price to Oracle.
    performSwaps(tokenA, simpleAmount(100, tokenA), tokenB, fee, 10);
    simpleStrategies = new SimpleStrategies();
  }

  function testExample() public {
    assertTrue(true);
  }

  function testAttachStrategy() public {
    RangePool privateRangePool = _createRangePoolAndAttachStrategy();

    assertTrue(
      rangePoolManager.isRegistered(address(privateRangePool), address(simpleStrategies)),
      'Registered Strategy'
    );
  }

  function testCompound() public {
    RangePool privateRangePool = _createRangePoolAndAttachStrategy();
    _privatePoolAddLiquidity(privateRangePool);
    performSwaps(tokenA, simpleAmount(100, tokenA), tokenB, fee, 10);

    (uint256 initialBalance0, uint256 initialBalance1) = _tokenBalances(
      privateRangePool.pool().token0(),
      privateRangePool.pool().token1()
    );

    (uint256 fee0, uint256 fee1) = INonfungiblePositionManager(RangePoolFactory(rangePoolFactory).positionManager())
      .fees(privateRangePool.tokenId());

    (, , , , , , , uint128 initialLiquidity, , , , ) = INonfungiblePositionManager(
      RangePoolFactory(rangePoolFactory).positionManager()
    ).positions(privateRangePool.tokenId());

    assertTrue(fee0 != 0, 'Fees accrued');
    assertTrue(fee1 != 0, 'Fees accrued');

    SimpleStrategies.CompoundReturns memory compoundReturns = simpleStrategies.compound(privateRangePool, 1_00);

    (, , , , , , , uint128 currentLiquidity, , , , ) = INonfungiblePositionManager(
      RangePoolFactory(rangePoolFactory).positionManager()
    ).positions(privateRangePool.tokenId());

    (uint256 currentBalance0, uint256 currentBalance1) = _tokenBalances(
      privateRangePool.pool().token0(),
      privateRangePool.pool().token1()
    );

    assertTrue(compoundReturns.addedLiquidity != 0);
    assertTrue(currentBalance0 == initialBalance0 + compoundReturns.amountRefunded0);
    assertTrue(currentBalance1 == initialBalance1 + compoundReturns.amountRefunded1);
    assertTrue(currentLiquidity == initialLiquidity + compoundReturns.addedLiquidity);
    assertTrue(ERC20(privateRangePool.pool().token0()).balanceOf(address(simpleStrategies)) == 0);
    assertTrue(ERC20(privateRangePool.pool().token1()).balanceOf(address(simpleStrategies)) == 0);
  }

  //
  // function stack(address token, uint16 slippage) internal {
  //   (, uint256 ibToken0, uint256 ibToken1) = _intialBalances();
  //   uint256 initialBalance = (token == rangePool.pool().token0()) ? ibToken0 : ibToken1;
  //   uint256 amount = simpleStrategies.stack(rangePool, token, slippage);
  //
  //   logr('stack()', ['amount', '0', '0', '0', '0', '0'], [uint256(amount), 0, 0, 0, 0, 0]);
  //
  //   assertTrue(amount > 0);
  //   assertTrue(ERC20(token).balanceOf(address(this)) == initialBalance.add(amount));
  // }

  function _privatePoolAddLiquidity(RangePool _rangePool)
    private
    returns (
      uint128 _liquidityAdded,
      uint256 _amountAdded0,
      uint256 _amountAdded1,
      uint256 _amountRefunded0,
      uint256 _amountRefunded1
    )
  {
    uint256 _amount0 = 10_000 ether; // DAI
    uint256 _amount1 = 10 ether; // WETH
    uint16 _slippage = 1_00;

    _approveAndDeal(tokenB, tokenA, _amount0, _amount1, address(rangePoolManager), address(this));

    (_liquidityAdded, _amountAdded0, _amountAdded1, _amountRefunded0, _amountRefunded1) = rangePoolManager.addLiquidity(
      _rangePool,
      _amount0,
      _amount1,
      _slippage
    );
  }

  function _createRangePoolAndAttachStrategy() private returns (RangePool _rangePool) {
    _rangePool = _createRangePool();
    rangePoolManager.attach(address(_rangePool), address(simpleStrategies));
    return _rangePool;
  }

  function _createRangePool() private returns (RangePool _rangePool) {
    _rangePool = RangePool(
      rangePoolManager.createPrivateRangePool(tokenA, tokenB, fee, oracleSeconds, lowerLimitB, upperLimitB)
    );
  }

  function _tokenBalances(address _tokenA, address _tokenB) public view returns (uint256 _amountA, uint256 _amountB) {
    _amountA = ERC20(_tokenA).balanceOf(address(this));
    _amountB = ERC20(_tokenB).balanceOf(address(this));
  }

  function _approveAndDeal(
    address _tokenA,
    address _tokenB,
    uint256 _amountA,
    uint256 _amountB,
    address _spender,
    address _receiver
  ) internal {
    ERC20(_tokenA).approve(address(_spender), type(uint256).max);
    ERC20(_tokenB).approve(address(_spender), type(uint256).max);
    deal(_tokenA, _receiver, _amountA);
    deal(_tokenB, _receiver, _amountB);
  }
}
