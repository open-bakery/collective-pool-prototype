// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.8.0;
pragma abicoder v2;

import './AStrategy.t.sol';
import '../src/strategies/Compound.sol';
import '@uniswap/v3-periphery/contracts/libraries/PositionValue.sol';

contract CompoundTest is AStrategyTest {
  using PositionValue for INonfungiblePositionManager;
  Compound compound;

  function setUp() public override {
    super.setUp();
    compound = new Compound();
  }

  function testCompound() public {
    RangePool rp = _createRangePoolAndAttachStrategy(address(compound));
    _addLiquidity(rp);
    performSwaps(tokenA, simpleAmount(100, tokenA), tokenB, fee, 10);

    (uint256 initialBalance0, uint256 initialBalance1) = _tokenBalances(rp.pool().token0(), rp.pool().token1());

    (uint256 fee0, uint256 fee1) = INonfungiblePositionManager(RangePoolFactory(rangePoolFactory).positionManager())
      .fees(rp.tokenId());

    (, , , , , , , uint128 initialLiquidity, , , , ) = INonfungiblePositionManager(
      RangePoolFactory(rangePoolFactory).positionManager()
    ).positions(rp.tokenId());

    assertTrue(fee0 != 0, 'Fees accrued');
    assertTrue(fee1 != 0, 'Fees accrued');

    Compound.CompoundReturns memory compoundReturns = compound.compound(rp, 1_00);

    (, , , , , , , uint128 currentLiquidity, , , , ) = INonfungiblePositionManager(
      RangePoolFactory(rangePoolFactory).positionManager()
    ).positions(rp.tokenId());

    (uint256 currentBalance0, uint256 currentBalance1) = _tokenBalances(rp.pool().token0(), rp.pool().token1());

    assertTrue(compoundReturns.addedLiquidity != 0);
    assertTrue(currentBalance0 == initialBalance0 + compoundReturns.amountRefunded0);
    assertTrue(currentBalance1 == initialBalance1 + compoundReturns.amountRefunded1);
    assertTrue(currentLiquidity == initialLiquidity + compoundReturns.addedLiquidity);
    assertTrue(ERC20(rp.pool().token0()).balanceOf(address(compound)) == 0);
    assertTrue(ERC20(rp.pool().token1()).balanceOf(address(compound)) == 0);
  }

  function testAStrategyPrivatePoolRevert() public {
    RangePool rp = _createRangePoolAndAttachStrategy(address(compound));
    _addLiquidity(rp);
    performSwaps(tokenA, simpleAmount(100, tokenA), tokenB, fee, 10);

    address prankster = address(0xdad);
    vm.prank(prankster);
    vm.expectRevert(bytes('AStrategy: Range Pool is private'));
    compound.compound(rp, 1_00);
  }
}
