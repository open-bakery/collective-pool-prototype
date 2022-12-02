// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.9.0;
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@uniswap/v3-periphery/contracts/libraries/PositionValue.sol';

import '../src/utility/TestHelpers.sol';

contract RangePoolManagerTest is TestHelpers, IERC721Receiver {
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
  }

  function testCreatePrivateRangePool() public {
    RangePool privateRangePool = _createRangePool();

    assertTrue(
      address(privateRangePool.pool()) == Helper.getPoolAddress(tokenA, tokenB, fee, rangePoolFactory.uniswapFactory())
    );

    assertTrue(privateRangePool.owner() == address(rangePoolManager));
    assertTrue(rangePoolManager.rangePoolOwner(address(privateRangePool)) == address(this));
  }

  function testPrivatePoolAddLiquidity() public {
    RangePool privateRangePool = _createRangePool();

    (uint128 liquidityAdded, uint256 amountAdded0, uint256 amountAdded1, , ) = _privatePoolAddLiquidity(
      privateRangePool
    );

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
    RangePool privateRangePool = _createRangePool();

    address prankster = address(0xdad);
    _approveAndDeal(tokenB, tokenA, amount0, amount1, address(rangePoolManager), prankster);
    vm.prank(prankster);
    vm.expectRevert(bytes('RangePoolManagerBase: Range Pool is private'));
    rangePoolManager.addLiquidity(privateRangePool, amount0, amount1, slippage);
  }

  function testPrivatePoolRemoveLiquidity() public {
    RangePool privateRangePool = _createRangePool();
    (uint128 liquidityAdded, , , , ) = _privatePoolAddLiquidity(privateRangePool);
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

    assertTrue(expected0 == removed0);
    assertTrue(expected1 == removed1);
    assertTrue(currentBalance0 == prevBalance0 + removed0);
    assertTrue(currentBalance1 == prevBalance1 + removed1);
  }

  function testPrivatePoolRemoveLiquidityRevert() public {
    RangePool privateRangePool = _createRangePool();
    (uint128 liquidityAdded, , , , ) = _privatePoolAddLiquidity(privateRangePool);
    address prankster = address(0xdad);
    vm.prank(prankster);
    vm.expectRevert(bytes('RangePoolManagerBase: Range Pool is private'));
    rangePoolManager.removeLiquidity(privateRangePool, liquidityAdded, 1_00);
  }

  function testPrivatePoolClaimNFT() public {
    RangePool privateRangePool = _createRangePool();
    _privatePoolAddLiquidity(privateRangePool);
    rangePoolManager.claimNFT(privateRangePool, address(this));

    assertTrue(
      INonfungiblePositionManager(RangePoolFactory(rangePoolFactory).positionManager()).ownerOf(
        privateRangePool.tokenId()
      ) == address(this),
      'Change NFT ownership'
    );
  }

  function testPrivatePoolClaimNFTRevert() public {
    RangePool privateRangePool = _createRangePool();
    _privatePoolAddLiquidity(privateRangePool);

    address prankster = address(0xdad);
    vm.prank(prankster);
    vm.expectRevert(bytes('RangePoolManagerBase: Only private pool owners can claim NFTs'));
    rangePoolManager.claimNFT(privateRangePool, prankster);
  }

  function testPrivatePoolCollectFees() public {
    RangePool privateRangePool = _createRangePool();
    _privatePoolAddLiquidity(privateRangePool);
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
    RangePool privateRangePool = _createRangePool();
    _privatePoolAddLiquidity(privateRangePool);
    performSwaps(tokenA, simpleAmount(100, tokenA), tokenB, fee, 10);

    address prankster = address(0xdad);
    vm.prank(prankster);
    vm.expectRevert(bytes('RangePoolManagerBase: Range Pool is private'));
    rangePoolManager.collectFees(privateRangePool);
  }

  function testPrivatePoolUpdateRange() public {
    RangePool privateRangePool = _createRangePool();
    _privatePoolAddLiquidity(privateRangePool);
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
    RangePool privateRangePool = _createRangePool();
    _privatePoolAddLiquidity(privateRangePool);
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
    RangePool privateRangePool = _createRangePool();
    _privatePoolAddLiquidity(privateRangePool);

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
    vm.expectRevert(bytes('RangePoolManagerBase: Range Pool is private'));

    rangePoolManager.updateRange(privateRangePool, token1, newLowerRange, newUpperRange, 1_00);
  }

  function testPoolManagerAdmin() public {
    RangePool privateRangePool = _createRangePool();

    assertTrue(rangePoolManager.isRangePoolAdmin(address(privateRangePool), address(this)), 'Admin registration');
  }

  function testAttachStrategy() public {
    RangePool privateRangePool = _createRangePool();
    address strategy = address(0x111);
    rangePoolManager.attach(address(privateRangePool), strategy);

    assertTrue(rangePoolManager.isRegistered(address(privateRangePool), strategy), 'Strategy registration');
  }

  function testAttachStrategyRevert() public {
    RangePool privateRangePool = _createRangePool();
    address strategy = address(0x111);
    address prankster = address(0xdad);
    vm.prank(prankster);
    vm.expectRevert(bytes('RangePoolManagerBase: Caller not range pool admin'));
    rangePoolManager.attach(address(privateRangePool), strategy);
  }

  function testEthTransactionRevert() public {
    RangePool privateRangePool = _createRangePool();
    vm.expectRevert(bytes('RangePoolManager: Eth not supported for this pool.'));
    rangePoolManager.addLiquidity{ value: 1 ether }(privateRangePool, 0, 0, 1_00);
  }

  function testEthTransaction() public {
    rangePoolManager = new RangePoolManager(address(rangePoolFactory), tokenA);
    RangePool privateRangePool = _createRangePool();
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

  function onERC721Received(
    address operator,
    address from,
    uint256 tokenId,
    bytes calldata data
  ) external pure override returns (bytes4) {
    operator;
    from;
    tokenId;
    data;
    return bytes4(keccak256('onERC721Received(address,address,uint256,bytes)'));
  }

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
