// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.9.0;
pragma abicoder v2;

import '@uniswap/v3-periphery/contracts/libraries/PositionValue.sol';

import '../src/libraries/Helper.sol';
import '../src/libraries/Conversion.sol';

import './ARangePool.t.sol';

contract RangePoolTest is ARangePoolTest {
  using PositionValue for INonfungiblePositionManager;
  using SafeERC20 for ERC20;
  using SafeMath for uint256;
  using SafeMath for uint128;

  function setUp() public override {
    super.setUp();
    rangePool = new RangePool(
      IRangePool.DeploymentParameters({
        uniswapFactory: address(uniswapFactory),
        uniswapRouter: address(uniswapRouter),
        positionManager: address(positionManager),
        tokenA: tokenA,
        tokenB: tokenB,
        fee: fee,
        oracleSeconds: oracleSeconds,
        lowerLimitInTokenB: lowerLimitB,
        upperLimitInTokenB: upperLimitB
      })
    );
  }

  function testDeployment() public {
    (int24 lowerTick, int24 upperTick) = Helper.validateAndConvertLimits(
      rangePool.pool(),
      tokenB,
      lowerLimitB,
      upperLimitB
    );

    assertTrue(
      address(rangePool.pool()) == Helper.getPoolAddress(tokenA, tokenB, fee, address(uniswapFactory)),
      'Pool address check'
    );
    assertTrue(rangePool.lowerTick() == lowerTick, 'Lower tick check');
    assertTrue(rangePool.upperTick() == upperTick, 'Upper tick check');
  }

  function testAddLiquidity() public {
    uint160 sqrtRatioX96 = Conversion.sqrtPriceX96(rangePool.pool());

    (
      uint128 liquidityAdded,
      uint256 amountAdded0,
      uint256 amountAdded1,
      uint256 amountRefunded0,
      uint256 amountRefunded1
    ) = _addLiquidity();

    (uint256 currentBalance0, uint256 currentBalance1) = _tokenBalances(
      rangePool.pool().token0(),
      rangePool.pool().token1()
    );

    assertTrue(
      Helper.positionLiquidity(rangePool.positionManager(), rangePool.tokenId()) == liquidityAdded,
      'Position Liquidity check'
    );
    assertTrue(liquidityAdded != 0, 'Liquidity != 0 check');
    assertTrue(currentBalance0 == amountRefunded0, 'Balance0 check');
    assertTrue(currentBalance1 == amountRefunded1, 'Balance0 check');
    (uint256 pos0, uint256 pos1) = rangePool.positionManager().principal(rangePool.tokenId(), sqrtRatioX96);
    assertTrue(isCloseTo(pos0, amountAdded0, pos0 / 100), 'Position0 check');
    assertTrue(isCloseTo(pos1, amountAdded1, pos1 / 100), 'Position1 check');
  }

  function testRemoveLiquidity() public {
    (uint128 liquidityAdded, , , , ) = _addLiquidity();

    uint128 liquidityToRemove = liquidityAdded / 2;

    (uint256 initialBalance0, uint256 initialBalance1) = _tokenBalances(
      rangePool.pool().token0(),
      rangePool.pool().token1()
    );

    (uint256 amountRemoved0, uint256 amountRemoved1) = rangePool.removeLiquidity(liquidityToRemove, 1_00);

    assertTrue(_getLiquidity() == liquidityAdded.sub(uint256(liquidityToRemove)), 'Liquidity Check');
    assertTrue(
      ERC20(rangePool.pool().token0()).balanceOf(address(this)) == initialBalance0.add(amountRemoved0),
      'Balance0 check'
    );
    assertTrue(
      ERC20(rangePool.pool().token1()).balanceOf(address(this)) == initialBalance1.add(amountRemoved1),
      'Balance1 check'
    );
  }

  function testCollectFees() public {
    _addLiquidity();
    performSwaps(tokenA, simpleAmount(100, tokenA), tokenB, fee, 10);
    (uint256 initialBalance0, uint256 initialBalance1) = _tokenBalances(
      rangePool.pool().token0(),
      rangePool.pool().token1()
    );
    (, , uint256 amountCollected0, uint256 amountCollected1) = rangePool.collectFees();

    assertTrue(amountCollected0 != 0, 'Collection0 check');
    assertTrue(amountCollected1 != 0, 'Collection1 check');
    assertTrue(
      ERC20(rangePool.pool().token0()).balanceOf(address(this)) == initialBalance0.add(amountCollected0),
      'Balance0 check'
    );
    assertTrue(
      ERC20(rangePool.pool().token1()).balanceOf(address(this)) == initialBalance1.add(amountCollected1),
      'Balance1 check'
    );
  }

  function testUpdateRange() public {
    address token = tokenB; // DAI
    uint256 lowerLimit = 800 ether;
    uint256 upperLimit = 1500 ether;

    _addLiquidity();
    rangePool.updateRange(token, lowerLimit, upperLimit, 1_00);

    (int24 lowerTick, int24 upperTick) = Helper.validateAndConvertLimits(
      rangePool.pool(),
      token,
      lowerLimit,
      upperLimit
    );

    assertTrue(lowerTick == rangePool.lowerTick(), 'Lower tick check');
    assertTrue(upperTick == rangePool.upperTick(), 'Upper tick check');
  }

  function testUpdateRangeRevert() public {
    address token = tokenB; // DAI
    uint256 lowerLimit = 800 ether;
    uint256 upperLimit = 1500 ether;

    vm.expectRevert(bytes('UpdateRange: Position must have liquidity'));
    rangePool.updateRange(token, lowerLimit, upperLimit, 1_00);
  }

  function testClaimNFT() public {
    _addLiquidity();
    uint256 tokenId = rangePool.tokenId();

    rangePool.claimNFT(address(this));

    assertTrue(rangePool.positionManager().ownerOf(tokenId) == address(this), 'NFT Ownership check');
  }

  function testClaimNFTRevertOwnership() public {
    _addLiquidity();
    vm.prank(address(0x1));
    vm.expectRevert(bytes('Ownable: caller is not the owner'));
    rangePool.claimNFT(address(this));
  }

  function testClaimNFTRevertNoLiquidity() public {
    vm.expectRevert(bytes('RangePool: No position available'));
    rangePool.claimNFT(address(this));
  }

  function _getLiquidity() internal view returns (uint128 _liquidity) {
    _liquidity = Helper.positionLiquidity(rangePool.positionManager(), rangePool.tokenId());
  }

  function _addLiquidity()
    internal
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

    _approveAndDeal(tokenB, tokenA, _amount0, _amount1, address(rangePool), address(this));

    (_liquidityAdded, _amountAdded0, _amountAdded1, _amountRefunded0, _amountRefunded1) = rangePool.addLiquidity(
      _amount0,
      _amount1,
      _slippage
    );
  }
}
