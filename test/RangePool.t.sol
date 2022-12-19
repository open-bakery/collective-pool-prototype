// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.9.0;
pragma abicoder v2;

import '../src/libraries/Helper.sol';
import '@uniswap/v3-periphery/contracts/libraries/PositionValue.sol';

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

    assertTrue(rangePool.lowerTick() == lowerTick);
    assertTrue(rangePool.upperTick() == upperTick);
  }

  // function testAddLiquidity() public {
  //   uint256 amount0 = 200_000 ether;
  //   uint256 amount1 = 100 ether;
  //   uint16 slippage = 10_00;

  //   deal(rangePool.pool().token0(), address(this), amount0);
  //   deal(rangePool.pool().token1(), address(this), amount1);

  //   (
  //     uint128 liquidityAdded,
  //     uint256 amountAdded0,
  //     uint256 amountAdded1,
  //     uint256 amountRefunded0,
  //     uint256 amountRefunded1
  //   ) = rangePool.addLiquidity(amount0, amount1, slippage);

  //   assertTrue(Helper.positionLiquidity(rangePool.positionManager(), rangePool.tokenId()) == liquidityAdded);
  //   assertTrue(liquidityAdded > 0);
  // }

  // function increaseLiquidity(
  //   uint256 amount0,
  //   uint256 amount1,
  //   uint16 slippage
  // ) internal {
  //   deal(rangePool.pool().token0(), address(this), amount0);
  //   deal(rangePool.pool().token1(), address(this), amount1);

  //   (uint256 iLiquidity, uint256 ibToken0, uint256 ibToken1) = _intialBalances();

  //   (uint128 liquidityAdded, uint256 amount0Added, uint256 amount1Added, , ) = rangePool.addLiquidity(
  //     amount0,
  //     amount1,
  //     slippage
  //   );

  //   logr(
  //     'testIncreaseLiquidity()',
  //     ['liquidityAdded', 'amount0Added', 'amount1Added', '0', '0', '0'],
  //     [uint256(liquidityAdded), amount0Added, amount1Added, 0, 0, 0]
  //   );

  //   assertTrue(
  //     Helper.positionLiquidity(rangePool.positionManager(), rangePool.tokenId()) ==
  //       uint256(liquidityAdded).add(iLiquidity)
  //   );
  //   assertTrue(liquidityAdded > 0);
  // }

  // function removeLiquidity(uint128 liquidity, uint16 slippage) internal {
  //   uint128 initialLiquidity = Helper.positionLiquidity(rangePool.positionManager(), rangePool.tokenId());

  //   (uint256 ibTokenLP, uint256 ibToken0, uint256 ibToken1) = _intialBalances();

  //   (uint256 amountDecreased0, uint256 amountDecreased1) = rangePool.removeLiquidity(liquidity, slippage);

  //   logr(
  //     'decreaseLiquidity()',
  //     ['amountDecreased0', 'amountDecreased1', '0', '0', '0', '0'],
  //     [uint256(amountDecreased0), amountDecreased1, 0, 0, 0, 0]
  //   );

  //   assertTrue(_getLiquidity(rangePool) == initialLiquidity.sub(uint256(liquidity)));
  //   assertTrue(ERC20(rangePool.pool().token0()).balanceOf(address(this)) == ibToken0.add(amountDecreased0));
  //   assertTrue(ERC20(rangePool.pool().token1()).balanceOf(address(this)) == ibToken1.add(amountDecreased1));
  // }

  // function collectFees() internal {
  //   (uint256 ibTokenLP, uint256 ibToken0, uint256 ibToken1) = _intialBalances();
  //   (address token0, address token1, uint256 amountCollected0, uint256 amountCollected1) = rangePool.collectFees();

  //   logr(
  //     'collectFees()',
  //     ['amountCollected0', 'amountCollected1', '0', '0', '0', '0'],
  //     [uint256(amountCollected0), amountCollected1, 0, 0, 0, 0]
  //   );

  //   assertTrue(ERC20(rangePool.pool().token0()).balanceOf(address(this)) == ibToken0.add(amountCollected0));
  //   assertTrue(ERC20(rangePool.pool().token1()).balanceOf(address(this)) == ibToken1.add(amountCollected1));
  // }

  // function updateRange(
  //   address token,
  //   uint256 lowerLimit,
  //   uint256 upperLimit,
  //   uint16 slippage
  // ) internal {
  //   (uint128 addedLiquidity, uint256 addedAmount0, uint256 addedAmount1, , ) = rangePool.updateRange(
  //     token,
  //     lowerLimit,
  //     upperLimit,
  //     slippage
  //   );

  //   uint256 newLowerLimit = lens.lowerLimit(rangePool);
  //   uint256 newUpperLimit = lens.upperLimit(rangePool);

  //   logr(
  //     'updateRange()',
  //     ['addedLiquidity', 'addedAmount0', 'addedAmount1', 'newLowerLimit', 'newUpperLimit', '0'],
  //     [uint256(addedLiquidity), addedAmount0, addedAmount1, newLowerLimit, newUpperLimit, 0]
  //   );
  // }

  // function _getLiquidity(RangePool _rp) internal view returns (uint128 _liquidity) {
  //   _liquidity = Helper.positionLiquidity(rangePool.positionManager(), rangePool.tokenId());
  // }

  // function _intialBalances()
  //   internal
  //   view
  //   returns (
  //     uint256 _liquidity,
  //     uint256 _amount0,
  //     uint256 _amount1
  //   )
  // {
  //   _liquidity = _getLiquidity(rangePool);
  //   _amount0 = ERC20(rangePool.pool().token0()).balanceOf(address(this));
  //   _amount1 = ERC20(rangePool.pool().token1()).balanceOf(address(this));
  // }
}
