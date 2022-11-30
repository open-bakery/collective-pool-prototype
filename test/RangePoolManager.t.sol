// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.9.0;
pragma abicoder v2;

import '@uniswap/v3-periphery/contracts/libraries/PositionValue.sol';

import '../src/utility/TestHelpers.sol';

contract RangePoolManagerTest is TestHelpers {
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
  }

  function testCreatePrivateRangePool() public {
    address privateRangePool = _createRangePool();

    assertTrue(
      address(RangePool(privateRangePool).pool()) ==
        Helper.getPoolAddress(tokenA, tokenB, fee, rangePoolFactory.uniswapFactory())
    );

    assertTrue(RangePool(privateRangePool).owner() == address(rangePoolManager));
    assertTrue(rangePoolManager.poolController(privateRangePool) == address(this));
  }

  function testPrivatePoolAddLiquidity() public {
    uint256 amount0 = 10_000 ether; // DAI
    uint256 amount1 = 10 ether; // WETH
    uint16 slippage = 10_00;

    address privateRangePool = _createRangePool();

    _approveAndDeal(tokenB, tokenA, amount0, amount1, address(rangePoolManager));

    (uint256 initialBalanceA, uint256 initialBalanceB) = _tokenBalances(tokenA, tokenB);

    (
      uint128 liquidityAdded,
      uint256 amountAdded0,
      uint256 amountAdded1,
      uint256 amountRefunded0,
      uint256 amountRefunded1
    ) = rangePoolManager.addLiquidity(privateRangePool, amount0, amount1, 1_00);

    (uint256 balanceA, uint256 balanceB) = _tokenBalances(tokenA, tokenB);

    assertTrue(
      Helper.positionLiquidity(
        INonfungiblePositionManager(rangePoolFactory.positionManager()),
        RangePool(privateRangePool).tokenId()
      ) == liquidityAdded,
      'Liquidity balance check'
    );

    assertTrue(ERC20(tokenA).balanceOf(address(rangePoolManager)) == 0);
    assertTrue(ERC20(tokenA).balanceOf(address(privateRangePool)) == 0);
    assertTrue(ERC20(tokenB).balanceOf(address(rangePoolManager)) == 0);
    assertTrue(ERC20(tokenB).balanceOf(address(privateRangePool)) == 0);

    (uint256 positionAmount0, uint256 positionAmount1) = INonfungiblePositionManager(rangePoolFactory.positionManager())
      .principal(RangePool(privateRangePool).tokenId(), Conversion.sqrtPriceX96(RangePool(privateRangePool).pool()));

    assertTrue(isCloseTo(amountAdded0, positionAmount0, 10), 'Position Balance of Token 0');
    assertTrue(isCloseTo(amountAdded1, positionAmount1, 10), 'Position Balance of Token 1');
    // vm.expectRevert(bytes('State not set correctly for continuation'));
  }

  function _tokenBalances(address tokenA, address tokenB) public view returns (uint256 amountA, uint256 amountB) {
    amountA = ERC20(tokenA).balanceOf(address(this));
    amountB = ERC20(tokenB).balanceOf(address(this));
  }

  function _createRangePool() private returns (address rangePool) {
    rangePool = rangePoolManager.createPrivateRangePool(tokenA, tokenB, fee, oracleSeconds, lowerLimitB, upperLimitB);
  }

  function _approveAndDeal(
    address _tokenA,
    address _tokenB,
    uint256 _amountA,
    uint256 _amountB,
    address _spender
  ) internal {
    ERC20(_tokenA).approve(address(_spender), type(uint256).max);
    ERC20(_tokenB).approve(address(_spender), type(uint256).max);
    deal(_tokenA, address(this), _amountA);
    deal(_tokenB, address(this), _amountB);
  }
}
