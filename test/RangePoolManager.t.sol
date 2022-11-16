// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.9.0;
pragma abicoder v2;

import '../src/utility/Utils.sol';

contract RangePoolManagerTest is Utils {
  address public tokenA;
  address public tokenB;
  uint24 public fee;
  uint256 public lowerLimitB;
  uint256 public upperLimitB;

  function setUp() public {
    deployBase();
    rangePoolManager = new RangePoolManager(address(rangePoolFactory), WETH);

    tokenA = WETH;
    tokenB = USDC;
    fee = 500;
    lowerLimitB = 1_000_000000;
    upperLimitB = 2_000_000000;
  }

  function testAddLiquidity() public {
    _approveAndDeal(tokenA, tokenB, 1 ether, 1_000_000000, address(rangePoolManager));
    // rangePoolManager.addLiquidity(rangePool, );
    assertTrue(true);
  }

  function testAddLiquidityDirectlyToRangePool() public {
    rangePool = RangePool(rangePoolManager.createRangePool(tokenA, tokenB, fee, lowerLimitB, upperLimitB, false));
    _approveAndDeal(tokenA, tokenB, 1 ether, 1_000_000000, address(rangePool));
    // rangePool.addLiquidity();
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
