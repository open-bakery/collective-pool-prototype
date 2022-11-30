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

  struct TestParams {
    uint256 amount0;
    uint256 amount1;
    uint16 slippage;
    address privateRangePool;
  }

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
    address privateRangePool = _createRangePool();

    (uint256 initialBalanceA, uint256 initialBalanceB) = _tokenBalances(tokenA, tokenB);

    (
      uint128 liquidityAdded,
      uint256 amountAdded0,
      uint256 amountAdded1,
      uint256 amountRefunded0,
      uint256 amountRefunded1
    ) = _privatePoolAddLiquidity(privateRangePool);

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

    assertTrue(isCloseTo(amountAdded0, positionAmount0, 1), 'Position Balance of Token 0');
    assertTrue(isCloseTo(amountAdded1, positionAmount1, 1), 'Position Balance of Token 1');
  }

  function testPrivatePoolAddLiquitidyRevert() public {
    uint256 amount0 = 10_000 ether; // DAI
    uint256 amount1 = 10 ether; // WETH
    uint16 slippage = 1_00;
    address privateRangePool = _createRangePool();

    address prankster = address(0xdad);
    _approveAndDeal(tokenB, tokenA, amount0, amount1, address(rangePoolManager), prankster);
    vm.prank(prankster);
    vm.expectRevert(bytes('RangePoolManager: Range Pool is private'));
    rangePoolManager.addLiquidity(privateRangePool, amount0, amount1, slippage);
  }

  function testPrivatePoolRemoveLiquidity() public {
    address privateRangePool = _createRangePool();
    (uint128 liquidityAdded, , , , ) = _privatePoolAddLiquidity(privateRangePool);
    uint128 liquidityToRemove = liquidityAdded / 2;
    (uint160 sqrtPriceX96, , , , , , ) = RangePool(privateRangePool).pool().slot0();

    (uint256 expected0, uint256 expected1) = Helper.getAmountsForLiquidity(
      sqrtPriceX96,
      RangePool(privateRangePool).lowerTick(),
      RangePool(privateRangePool).upperTick(),
      liquidityToRemove
    );

    (uint256 prevBalance0, uint256 prevBalance1) = _tokenBalances(
      RangePool(privateRangePool).pool().token0(),
      RangePool(privateRangePool).pool().token1()
    );

    (uint256 removed0, uint256 removed1) = rangePoolManager.removeLiquidity(privateRangePool, liquidityToRemove, 1_00);

    (uint256 currentBalance0, uint256 currentBalance1) = _tokenBalances(
      RangePool(privateRangePool).pool().token0(),
      RangePool(privateRangePool).pool().token1()
    );

    assertTrue(expected0 == removed0);
    assertTrue(expected1 == removed1);
    assertTrue(currentBalance0 == prevBalance0 + removed0);
    assertTrue(currentBalance1 == prevBalance1 + removed1);
  }

  function testPrivatePoolRemoveLiquidityRevert() public {
    address privateRangePool = _createRangePool();
    (uint128 liquidityAdded, , , , ) = _privatePoolAddLiquidity(privateRangePool);
    address prankster = address(0xdad);
    vm.prank(prankster);
    vm.expectRevert(bytes('RangePoolManager: Range Pool is private'));
    rangePoolManager.removeLiquidity(privateRangePool, liquidityAdded, 1_00);
  }

  function testPrivatePoolClaimNFT() public {
    address privateRangePool = _createRangePool();
    _privatePoolAddLiquidity(privateRangePool);
    rangePoolManager.claimNFT(privateRangePool, address(this));

    assertTrue(
      INonfungiblePositionManager(RangePoolFactory(rangePoolFactory).positionManager()).ownerOf(
        RangePool(privateRangePool).tokenId()
      ) == address(this),
      'Change NFT ownership'
    );
  }

  function testPrivatePoolClaimNFTRevert() public {
    address privateRangePool = _createRangePool();
    _privatePoolAddLiquidity(privateRangePool);

    address prankster = address(0xdad);
    vm.prank(prankster);
    vm.expectRevert(bytes('RangePoolManager: Only private pool owners can claim NFTs'));
    rangePoolManager.claimNFT(privateRangePool, prankster);
  }

  function onERC721Received(
    address operator,
    address from,
    uint256 tokenId,
    bytes calldata data
  ) external override returns (bytes4) {
    operator;
    from;
    tokenId;
    data;
    return bytes4(keccak256('onERC721Received(address,address,uint256,bytes)'));
  }

  function _privatePoolAddLiquidity(address rangePool)
    private
    returns (
      uint128 liquidityAdded,
      uint256 amountAdded0,
      uint256 amountAdded1,
      uint256 amountRefunded0,
      uint256 amountRefunded1
    )
  {
    uint256 amount0 = 10_000 ether; // DAI
    uint256 amount1 = 10 ether; // WETH
    uint16 slippage = 1_00;

    _approveAndDeal(tokenB, tokenA, amount0, amount1, address(rangePoolManager), address(this));

    (liquidityAdded, amountAdded0, amountAdded1, amountRefunded0, amountRefunded1) = rangePoolManager.addLiquidity(
      rangePool,
      amount0,
      amount1,
      slippage
    );
  }

  function _createRangePoolAndAddLiquidity(TestParams memory params) private returns (address privateRangePool) {
    privateRangePool = _createRangePool();
    _approveAndDeal(tokenB, tokenA, params.amount0, params.amount1, address(rangePoolManager), address(this));
  }

  function _createRangePool() private returns (address rangePool) {
    rangePool = rangePoolManager.createPrivateRangePool(tokenA, tokenB, fee, oracleSeconds, lowerLimitB, upperLimitB);
  }

  function _tokenBalances(address tokenA, address tokenB) public view returns (uint256 amountA, uint256 amountB) {
    amountA = ERC20(tokenA).balanceOf(address(this));
    amountB = ERC20(tokenB).balanceOf(address(this));
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
