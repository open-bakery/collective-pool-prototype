// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.8.0;
pragma abicoder v2;

import '@uniswap/v3-periphery/contracts/libraries/PositionValue.sol';
import '../src/utility/TestHelpers.sol';
import '../src/CollectivePoolSimpleStrategy.sol';

contract CollectivePoolSimpleStrategyTest is TestHelpers {
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
    rangePoolManager = new RangePoolManager(address(rangePoolFactory), address(0));
    // Performs swap to record price to Oracle.
    performSwaps(tokenA, simpleAmount(100, tokenA), tokenB, fee, 10);
    simpleStrategies = new SimpleStrategies();
  }

  function testCollectivePoolLPMint() public {
    // RangePool collectiveRangePool = _createCollectiveRangePool();
    // LiquidityProviderToken lp = LiquidityProviderToken(rangePoolManager.rangePoolLP(address(collectiveRangePool)));
    // uint256 id = collectiveRangePool.tokenId();
    // assertTrue(
    //   keccak256(abi.encodePacked(lp.symbol())) == keccak256(abi.encodePacked('LP_', Strings.toString(id))),
    //   'Token symbol'
    // );
    // assertTrue(lp.owner() == address(rangePoolManager), 'Token ownership');
  }

  function testCollectivePoolAddLiquidity() public {
    // RangePool collectiveRangePool = _createCollectiveRangePool();
    // (uint128 _liquidityAdded, , , , ) = _addLiquidity(collectiveRangePool);
    // LiquidityProviderToken lp = LiquidityProviderToken(rangePoolManager.rangePoolLP(address(collectiveRangePool)));
    // assertTrue(lp.balanceOf(address(this)) == _liquidityAdded);
    // assertTrue(_liquidityAdded != 0);
  }

  function testCollectivePoolRemoveLiquidity() public {
    // RangePool collectiveRangePool = _createCollectiveRangePool();
    // (uint128 _liquidityAdded, , , , ) = _addLiquidity(collectiveRangePool);
    // (uint256 initialBalance0, uint256 initialBalance1) = _tokenBalances(
    //   collectiveRangePool.pool().token0(),
    //   collectiveRangePool.pool().token1()
    // );
    // LiquidityProviderToken lp = LiquidityProviderToken(rangePoolManager.rangePoolLP(address(collectiveRangePool)));
    // uint256 liquidity = lp.balanceOf(address(this));
    // (uint256 amountRemoved0, uint256 amountRemoved1) = rangePoolManager.removeLiquidity(
    //   collectiveRangePool,
    //   uint128(liquidity),
    //   1_00
    // );
    // (uint256 currentBalance0, uint256 currentBalance1) = _tokenBalances(
    //   collectiveRangePool.pool().token0(),
    //   collectiveRangePool.pool().token1()
    // );
    // assertTrue(lp.balanceOf(address(this)) == 0, 'Liquidity check');
    // assertTrue(amountRemoved0 != 0, 'Removed amount0 check');
    // assertTrue(amountRemoved1 != 0, 'Removed amount1 check');
    // assertTrue(currentBalance0 == initialBalance0 + amountRemoved0, 'Balance0 check');
    // assertTrue(currentBalance1 == initialBalance1 + amountRemoved1, 'Balance1 check');
  }

  function testCollectivePoolRemoveLiquidityRevert() public {
    // RangePool collectiveRangePool = _createCollectiveRangePool();
    // (uint128 _liquidityAdded, , , , ) = _addLiquidity(collectiveRangePool);
    // vm.expectRevert(bytes('RangePoolManagerBase: Not enough liquidity balance'));
    // (uint256 amountRemoved0, uint256 amountRemoved1) = rangePoolManager.removeLiquidity(
    //   collectiveRangePool,
    //   uint128(_liquidityAdded * 2),
    //   1_00
    // );
  }

  function testCollectivePoolCollectFeesRevert() public {
    // RangePool collectiveRangePool = _createCollectiveRangePool();
    // _addLiquidity(collectiveRangePool);
    // performSwaps(tokenA, simpleAmount(100, tokenA), tokenB, fee, 10);
    // vm.expectRevert(bytes('RangePoolManagerBase: Only strategies can call this function'));
    // rangePoolManager.collectFees(collectiveRangePool);
  }

  function testCollectivePoolUpdateRangeRevert() public {
    // RangePool collectiveRangePool = _createCollectiveRangePool();
    // _addLiquidity(collectiveRangePool);
    // address token1 = collectiveRangePool.pool().token1();
    // uint256 newLowerRange = Conversion.convertTickToPriceUint(
    //   collectiveRangePool.lowerTick(),
    //   ERC20(collectiveRangePool.pool().token0()).decimals()
    // ) / 2;
    // uint256 newUpperRange = Conversion.convertTickToPriceUint(
    //   collectiveRangePool.upperTick(),
    //   ERC20(collectiveRangePool.pool().token0()).decimals()
    // ) * 2;
    // vm.expectRevert(bytes('RangePoolManagerBase: Only strategies can call this function'));
    // rangePoolManager.updateRange(collectiveRangePool, token1, newLowerRange, newUpperRange, 1_00);
  }

  function _createCollectiveRangePool() private returns (RangePool _rangePool) {
    // _rangePool = RangePool(
    //   rangePoolManager.createCollectiveRangePool(tokenA, tokenB, fee, oracleSeconds, lowerLimitB, upperLimitB)
    // );
  }

  function _addLiquidity(RangePool _rangePool)
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
