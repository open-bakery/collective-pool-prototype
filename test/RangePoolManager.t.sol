// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.9.0;
pragma abicoder v2;

import '@uniswap/v3-periphery/contracts/libraries/PositionValue.sol';

import '../src/LiquidityProviderToken.sol';
import './ARangePoolManager.t.sol';

contract RangePoolManagerTest is ARangePoolManagerTest {
  using PositionValue for INonfungiblePositionManager;

  function testCreatePrivateRangePool() public {
    RangePool privateRangePool = _createPrivateRangePool();
    LiquidityProviderToken lp = LiquidityProviderToken(rangePoolManager.rangePoolLP(address(privateRangePool)));
    uint256 id = privateRangePool.tokenId();

    assertTrue(
      keccak256(abi.encodePacked(lp.symbol())) == keccak256(abi.encodePacked('LP_', Strings.toString(id))),
      'Token symbol'
    );

    assertTrue(lp.owner() == address(rangePoolManager), 'Token ownership');

    assertTrue(
      address(privateRangePool.pool()) == Helper.getPoolAddress(tokenA, tokenB, fee, rangePoolFactory.uniswapFactory())
    );

    assertTrue(privateRangePool.owner() == address(rangePoolManager));
    assertTrue(rangePoolManager.rangePoolOwner(address(privateRangePool)) == address(this));
  }

  function testPrivatePoolAddLiquidity() public {
    RangePool privateRangePool = _createPrivateRangePool();
    LiquidityProviderToken lp = LiquidityProviderToken(rangePoolManager.rangePoolLP(address(privateRangePool)));

    (uint128 liquidityAdded, uint256 amountAdded0, uint256 amountAdded1, , ) = _addLiquidity(privateRangePool);

    assertTrue(lp.balanceOf(address(this)) == liquidityAdded, 'LP Balance Check');
    assertTrue(liquidityAdded != 0, 'Liquidity > 0');

    assertTrue(
      Helper.positionLiquidity(
        INonfungiblePositionManager(rangePoolFactory.positionManager()),
        privateRangePool.tokenId()
      ) == liquidityAdded,
      'Liquidity balance check'
    );

    assertTrue(ERC20(tokenA).balanceOf(address(rangePoolManager)) == 0);
    assertTrue(ERC20(tokenA).balanceOf(address(privateRangePool)) == 0);
    assertTrue(ERC20(tokenB).balanceOf(address(rangePoolManager)) == 0);
    assertTrue(ERC20(tokenB).balanceOf(address(privateRangePool)) == 0);

    (uint256 positionAmount0, uint256 positionAmount1) = INonfungiblePositionManager(rangePoolFactory.positionManager())
      .principal(privateRangePool.tokenId(), Conversion.sqrtPriceX96(privateRangePool.pool()));

    assertTrue(isCloseTo(amountAdded0, positionAmount0, 1), 'Position Balance of Token 0');
    assertTrue(isCloseTo(amountAdded1, positionAmount1, 1), 'Position Balance of Token 1');
  }

  function testPrivatePoolAddLiquitidyRevert() public {
    uint256 amount0 = 10_000 ether; // DAI
    uint256 amount1 = 10 ether; // WETH
    uint16 slippage = 1_00;
    RangePool privateRangePool = _createPrivateRangePool();

    address prankster = address(0xdad);
    _approveAndDeal(tokenB, tokenA, amount0, amount1, address(rangePoolManager), prankster);
    vm.prank(prankster);
    vm.expectRevert(bytes('RangePoolManagerBase: Caller not allowed in private pool'));
    rangePoolManager.addLiquidity(privateRangePool, amount0, amount1, slippage);
  }

  function testPrivatePoolRemoveLiquidity() public {
    RangePool privateRangePool = _createPrivateRangePool();
    LiquidityProviderToken lp = LiquidityProviderToken(rangePoolManager.rangePoolLP(address(privateRangePool)));
    (uint128 liquidityAdded, , , , ) = _addLiquidity(privateRangePool);
    uint128 liquidityToRemove = liquidityAdded / 2;
    (uint160 sqrtPriceX96, , , , , , ) = privateRangePool.pool().slot0();

    (uint256 expected0, uint256 expected1) = Helper.getAmountsForLiquidity(
      sqrtPriceX96,
      privateRangePool.lowerTick(),
      privateRangePool.upperTick(),
      liquidityToRemove
    );

    (uint256 prevBalance0, uint256 prevBalance1) = _tokenBalances(
      privateRangePool.pool().token0(),
      privateRangePool.pool().token1()
    );

    (uint256 removed0, uint256 removed1) = rangePoolManager.removeLiquidity(privateRangePool, liquidityToRemove, 1_00);

    (uint256 currentBalance0, uint256 currentBalance1) = _tokenBalances(
      privateRangePool.pool().token0(),
      privateRangePool.pool().token1()
    );

    assertTrue(lp.balanceOf(address(this)) == liquidityAdded - liquidityToRemove, 'Burn lp check');
    assertTrue(expected0 == removed0);
    assertTrue(expected1 == removed1);
    assertTrue(currentBalance0 == prevBalance0 + removed0);
    assertTrue(currentBalance1 == prevBalance1 + removed1);
  }

  function testPrivatePoolRemoveLiquidityRevert() public {
    RangePool privateRangePool = _createPrivateRangePool();
    (uint128 liquidityAdded, , , , ) = _addLiquidity(privateRangePool);
    address prankster = address(0xdad);
    vm.prank(prankster);
    vm.expectRevert(bytes('RangePoolManagerBase: Caller not allowed in private pool'));
    rangePoolManager.removeLiquidity(privateRangePool, liquidityAdded, 1_00);
  }

  function testPrivatePoolClaimNFT() public {
    RangePool privateRangePool = _createPrivateRangePool();
    _addLiquidity(privateRangePool);
    rangePoolManager.claimNFT(privateRangePool, address(this));

    assertTrue(
      INonfungiblePositionManager(RangePoolFactory(rangePoolFactory).positionManager()).ownerOf(
        privateRangePool.tokenId()
      ) == address(this),
      'Change NFT ownership'
    );
  }

  function testPrivatePoolClaimNFTRevert() public {
    RangePool privateRangePool = _createPrivateRangePool();
    _addLiquidity(privateRangePool);

    address prankster = address(0xdad);
    vm.prank(prankster);
    vm.expectRevert(bytes('RangePoolManagerBase: Caller not range pool owner'));
    rangePoolManager.claimNFT(privateRangePool, prankster);
  }

  function testPrivatePoolCollectFees() public {
    RangePool privateRangePool = _createPrivateRangePool();
    _addLiquidity(privateRangePool);
    performSwaps(tokenA, simpleAmount(100, tokenA), tokenB, fee, 10);

    (uint256 prevBalance0, uint256 prevBalance1) = _tokenBalances(
      privateRangePool.pool().token0(),
      privateRangePool.pool().token1()
    );

    (
      address tokenCollected0,
      address tokenCollected1,
      uint256 collectedFees0,
      uint256 collectedFees1
    ) = rangePoolManager.collectFees(privateRangePool);

    (uint256 currentBalance0, uint256 currentBalance1) = _tokenBalances(tokenCollected0, tokenCollected1);

    assertTrue(collectedFees0 != 0);
    assertTrue(collectedFees1 != 0);

    assertTrue(currentBalance0 == prevBalance0 + collectedFees0);
    assertTrue(currentBalance1 == prevBalance1 + collectedFees1);
  }

  function testPrivatePoolCollectFeesRevert() public {
    RangePool privateRangePool = _createPrivateRangePool();
    _addLiquidity(privateRangePool);
    performSwaps(tokenA, simpleAmount(100, tokenA), tokenB, fee, 10);

    address prankster = address(0xdad);
    vm.prank(prankster);
    vm.expectRevert(bytes('RangePoolManagerBase: Caller not allowed in private pool'));
    rangePoolManager.collectFees(privateRangePool);
  }

  function testPrivatePoolUpdateRange() public {
    RangePool privateRangePool = _createPrivateRangePool();
    _addLiquidity(privateRangePool);
    uint256 tokenId = privateRangePool.tokenId();
    performSwaps(tokenA, simpleAmount(100, tokenA), tokenB, fee, 10);

    uint256 newLowerRange = Conversion.convertTickToPriceUint(
      privateRangePool.lowerTick(),
      ERC20(privateRangePool.pool().token0()).decimals()
    ) / 2;

    uint256 newUpperRange = Conversion.convertTickToPriceUint(
      privateRangePool.upperTick(),
      ERC20(privateRangePool.pool().token0()).decimals()
    ) * 2;

    (uint128 liquidityAdded, , , , ) = rangePoolManager.updateRange(
      privateRangePool,
      privateRangePool.pool().token1(),
      newLowerRange,
      newUpperRange,
      1_00
    );

    assertTrue(liquidityAdded != 0, 'Liquidity added != 0');
    assertTrue(privateRangePool.tokenId() == tokenId + 1, 'New position created');
    assertTrue(
      Helper.positionLiquidity(
        INonfungiblePositionManager(RangePoolFactory(rangePoolFactory).positionManager()),
        tokenId + 1
      ) == liquidityAdded,
      'Liquidity has been added to position'
    );

    (int24 newLowerTick, int24 newUpperTick) = Conversion.convertLimitsToTicks(
      newLowerRange,
      newUpperRange,
      TICK_SPACING[fee],
      ERC20(privateRangePool.pool().token0()).decimals()
    );

    assertTrue(newLowerTick == privateRangePool.lowerTick(), 'LowerTick has been updated');
    assertTrue(newUpperTick == privateRangePool.upperTick(), 'UpperTick has been updated');
  }

  function testRefundPrivatePoolUpdateRange() public {
    RangePool privateRangePool = _createPrivateRangePool();
    _addLiquidity(privateRangePool);
    performSwaps(tokenA, simpleAmount(100, tokenA), tokenB, fee, 10);

    (uint256 initalBalance0, uint256 initalBalance1) = _tokenBalances(
      privateRangePool.pool().token0(),
      privateRangePool.pool().token1()
    );

    (, , , uint256 amountRefunded0, uint256 amountRefunded1) = rangePoolManager.updateRange(
      privateRangePool,
      privateRangePool.pool().token1(),
      Conversion.convertTickToPriceUint(
        privateRangePool.lowerTick(),
        ERC20(privateRangePool.pool().token0()).decimals()
      ) / 2,
      Conversion.convertTickToPriceUint(
        privateRangePool.upperTick(),
        ERC20(privateRangePool.pool().token0()).decimals()
      ) * 2,
      1_00
    );

    (uint256 currentBalance0, uint256 currentBalance1) = _tokenBalances(
      privateRangePool.pool().token0(),
      privateRangePool.pool().token1()
    );

    assertTrue(currentBalance0 == initalBalance0 + amountRefunded0, 'Test refund 0');
    assertTrue(currentBalance1 == initalBalance1 + amountRefunded1, 'Test refund 1');
  }

  function testPrivatePoolUpdateRangeRevert() public {
    RangePool privateRangePool = _createPrivateRangePool();
    _addLiquidity(privateRangePool);

    address token1 = privateRangePool.pool().token1();

    uint256 newLowerRange = Conversion.convertTickToPriceUint(
      privateRangePool.lowerTick(),
      ERC20(privateRangePool.pool().token0()).decimals()
    ) / 2;

    uint256 newUpperRange = Conversion.convertTickToPriceUint(
      privateRangePool.upperTick(),
      ERC20(privateRangePool.pool().token0()).decimals()
    ) * 2;

    address prankster = address(0xdad);
    vm.prank(prankster);
    vm.expectRevert(bytes('RangePoolManagerBase: Caller not allowed in private pool'));

    rangePoolManager.updateRange(privateRangePool, token1, newLowerRange, newUpperRange, 1_00);
  }

  function testAttachStrategy() public {
    RangePool privateRangePool = _createPrivateRangePool();
    address strategy = address(0x111);
    rangePoolManager.attach(address(privateRangePool), strategy);

    assertTrue(rangePoolManager.isRegistered(address(privateRangePool), strategy), 'Strategy registration');
  }

  function testAttachStrategyRevert() public {
    RangePool privateRangePool = _createPrivateRangePool();
    address strategy = address(0x111);
    address prankster = address(0xdad);
    vm.prank(prankster);
    vm.expectRevert(bytes('RangePoolManagerBase: Caller not range pool owner'));
    rangePoolManager.attach(address(privateRangePool), strategy);
  }

  function testEthTransactionRevert() public {
    RangePool privateRangePool = _createPrivateRangePool();
    vm.expectRevert(bytes('RangePoolManager: Eth not supported for this pool.'));
    rangePoolManager.addLiquidity{ value: 1 ether }(privateRangePool, 0, 0, 1_00);
  }

  function testEthTransaction() public {
    rangePoolManager = new RangePoolManager(address(rangePoolFactory), tokenA);
    RangePool privateRangePool = _createPrivateRangePool();
    (uint128 liquidityAdded, , , , ) = rangePoolManager.addLiquidity{ value: 1 ether }(privateRangePool, 0, 0, 1_00);

    assertTrue(
      Helper.positionLiquidity(
        INonfungiblePositionManager(rangePoolFactory.positionManager()),
        privateRangePool.tokenId()
      ) == liquidityAdded,
      'Liquidity balance check'
    );
    assertTrue(
      Helper.positionLiquidity(
        INonfungiblePositionManager(rangePoolFactory.positionManager()),
        privateRangePool.tokenId()
      ) != 0,
      'Added liquidity'
    );

    assertTrue(address(tokenA).balance == 1 ether);
  }

  function testDeployCollectiveRangePool() public {
    RangePool collectiveRangePool = _createCollectiveRangePool();
    assertTrue(rangePoolManager.rangePoolOwner(address(collectiveRangePool)) == address(0), 'No owner check');
    assertTrue(address(rangePoolManager.rangePoolLP(address(collectiveRangePool))) != address(0), 'LP minted check');
  }

  function testCollectiveRangePoolAddLiquidity() public {
    RangePool collectiveRangePool = _createCollectiveRangePool();
    (uint128 liquidityAdded, , , , ) = _addLiquidity(collectiveRangePool);
    LiquidityProviderToken lp = rangePoolManager.rangePoolLP(address(collectiveRangePool));
    assertTrue(lp.balanceOf(address(this)) == liquidityAdded, 'Liquidity Added Check');
  }

  function testCollectivePoolRemoveLiquidity() public {
    RangePool collectiveRangePool = _createCollectiveRangePool();
    _addLiquidity(collectiveRangePool);
    (uint256 initialBalance0, uint256 initialBalance1) = _tokenBalances(
      collectiveRangePool.pool().token0(),
      collectiveRangePool.pool().token1()
    );
    LiquidityProviderToken lp = LiquidityProviderToken(rangePoolManager.rangePoolLP(address(collectiveRangePool)));
    uint256 liquidity = lp.balanceOf(address(this));
    (uint256 amountRemoved0, uint256 amountRemoved1) = rangePoolManager.removeLiquidity(
      collectiveRangePool,
      uint128(liquidity),
      1_00
    );
    (uint256 currentBalance0, uint256 currentBalance1) = _tokenBalances(
      collectiveRangePool.pool().token0(),
      collectiveRangePool.pool().token1()
    );
    assertTrue(lp.balanceOf(address(this)) == 0, 'Liquidity check');
    assertTrue(amountRemoved0 != 0, 'Removed amount0 check');
    assertTrue(amountRemoved1 != 0, 'Removed amount1 check');
    assertTrue(currentBalance0 == initialBalance0 + amountRemoved0, 'Balance0 check');
    assertTrue(currentBalance1 == initialBalance1 + amountRemoved1, 'Balance1 check');
  }

  function testCollectivePoolRemoveLiquidityRevert() public {
    RangePool collectiveRangePool = _createCollectiveRangePool();
    (uint128 _liquidityAdded, , , , ) = _addLiquidity(collectiveRangePool);
    vm.expectRevert(bytes('RangePoolManagerBase: Not enough liquidity balance'));
    rangePoolManager.removeLiquidity(collectiveRangePool, uint128(_liquidityAdded * 2), 1_00);
  }

  function testCollectivePoolCollectFeesRevert() public {
    RangePool collectiveRangePool = _createCollectiveRangePool();
    _addLiquidity(collectiveRangePool);
    performSwaps(tokenA, simpleAmount(100, tokenA), tokenB, fee, 10);
    vm.expectRevert(bytes('RangePoolManagerBase: Caller not allowed in collective pool'));
    rangePoolManager.collectFees(collectiveRangePool);
  }

  function testCollectivePoolUpdateRangeRevert() public {
    RangePool collectiveRangePool = _createCollectiveRangePool();
    _addLiquidity(collectiveRangePool);
    address token1 = collectiveRangePool.pool().token1();
    uint256 newLowerRange = Conversion.convertTickToPriceUint(
      collectiveRangePool.lowerTick(),
      ERC20(collectiveRangePool.pool().token0()).decimals()
    ) / 2;
    uint256 newUpperRange = Conversion.convertTickToPriceUint(
      collectiveRangePool.upperTick(),
      ERC20(collectiveRangePool.pool().token0()).decimals()
    ) * 2;
    vm.expectRevert(bytes('RangePoolManagerBase: Caller not allowed in collective pool'));
    rangePoolManager.updateRange(collectiveRangePool, token1, newLowerRange, newUpperRange, 1_00);
  }
}
