// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';

import './RangePool.sol';

contract RangePoolFactory {
  IUniswapV3Factory public immutable uniswapFactory;
  ISwapRouter public immutable uniswapRouter;
  INonfungiblePositionManager public immutable positionManager;
  address public immutable WETH;

  event RangePoolDeployed(address indexed deployer, address indexed rangePool);

  constructor(
    address _uniswapFactory,
    address _uniswapRouter,
    address _positionManager,
    address _weth
  ) {
    positionManager = INonfungiblePositionManager(_positionManager);
    uniswapFactory = IUniswapV3Factory(_uniswapFactory);
    uniswapRouter = ISwapRouter(_uniswapRouter);
    WETH = _weth;
  }

  function deployRangePool(
    address tokenA,
    address tokenB,
    uint24 fee,
    uint256 lowerLimitInTokenB,
    uint256 upperLimitInTokenB
  ) external returns (address) {
    RangePool rangePool = new RangePool(tokenA, tokenB, fee, lowerLimitInTokenB, upperLimitInTokenB);
    rangePool.transferOwnership(msg.sender);

    emit RangePoolDeployed(msg.sender, address(rangePool));

    return address(rangePool);
  }
}
