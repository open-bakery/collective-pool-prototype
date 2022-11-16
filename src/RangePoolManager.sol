// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';

import '@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol';

import './RangePoolFactory.sol';
import './RangePool.sol';
import './LiquidityProviderToken.sol';

contract RangePoolManager is Ownable {
  using SafeERC20 for ERC20;

  struct PositionData {
    uint160 liquidity;
    uint256 clearedFees0;
    uint256 clearedFees1;
  }

  RangePoolFactory rangePoolFactory;

  address weth;

  mapping(address => bool) public isRegistered; // isRegistered[rangePool][strategy] = bool;
  mapping(address => address) poolController;
  mapping(address => address) public liquitityToken; // liquidityToken[rangePool] = address;
  mapping(address => mapping(address => PositionData)) public position; // position[rangePool][user] = PositionData;

  modifier onlyAllowed() {
    require(msg.sender == owner() || isRegistered[msg.sender] == true, 'RangePool:NA'); // Caller not allowed
    _;
  }

  event RangePoolCreated(address indexed rangePool);

  constructor(address rangePoolFactory_, address weth_) {
    rangePoolFactory = RangePoolFactory(rangePoolFactory_);
    weth = weth_;
  }

  function createRangePool(
    address tokenA,
    address tokenB,
    uint24 fee,
    uint256 lowerLimitInTokenB,
    uint256 upperLimitInTokenB,
    bool privatePool
  ) external returns (address rangePool) {
    rangePool = rangePoolFactory.deployRangePool(tokenA, tokenB, fee, lowerLimitInTokenB, upperLimitInTokenB);
    if (privatePool) poolController[rangePool] = msg.sender;
    emit RangePoolCreated(rangePool);
  }

  function addLiquidity(
    address rangePool,
    uint256 amount0,
    uint256 amount1,
    uint16 slippage
  )
    external
    payable
    returns (
      uint128 liquidityAdded,
      uint256 amountAdded0,
      uint256 amountAdded1
    )
  {
    if (poolController[rangePool] != address(0))
      require(poolController[rangePool] == msg.sender, 'RangePoolPositionManager: NPC'); //Not position controller

    ERC20(RangePool(rangePool).pool().token0()).safeApprove(rangePool, amount0);
    ERC20(RangePool(rangePool).pool().token1()).safeApprove(rangePool, amount1);

    (liquidityAdded, amountAdded0, amountAdded1) = RangePool(rangePool).addLiquidity(amount0, amount1, slippage);

    // PositionData memory cachePosition;

    if (liquitityToken[rangePool] == address(0))
      liquitityToken[rangePool] = address(new LiquidityProviderToken(RangePool(rangePool).tokenId()));

    address lp = liquitityToken[rangePool];
    _mint(address(lp), msg.sender, liquidityAdded);
  }

  function _mint(
    address _lpToken,
    address _recipient,
    uint256 _amount
  ) internal {
    LiquidityProviderToken(_lpToken).mint(_recipient, _amount);
  }

  // function _useWeth(uint256 token0Amount, uint256 token1Amount)
  //   internal
  //   returns (
  //     uint256,
  //     uint256,
  //     bool
  //   )
  // {
  //   bool _ethUsed = false;
  //   uint256 _eth = msg.value;
  //   if (_eth > 0) {
  //     IWETH9(weth).deposit{ value: _eth }();
  //
  //     if (pool.token0() == weth) {
  //       token0Amount = _eth;
  //       _ethUsed = true;
  //     } else if (pool.token1() == weth) {
  //       token1Amount = _eth;
  //       _ethUsed = true;
  //     }
  //   }
  //   return (token0Amount, token1Amount, _ethUsed);
  // }
}
