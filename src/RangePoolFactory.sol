// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';

import './interfaces/IRangePool.sol';
import './RangePool.sol';

contract RangePoolFactory {
  address public immutable uniswapFactory;
  address public immutable uniswapRouter;
  address public immutable positionManager;

  event RangePoolDeployed(address indexed deployer, address indexed rangePool);

  constructor(
    address _uniswapFactory,
    address _uniswapRouter,
    address _positionManager
  ) {
    positionManager = _positionManager;
    uniswapFactory = _uniswapFactory;
    uniswapRouter = _uniswapRouter;
  }

  function deployRangePool(
    address tokenA,
    address tokenB,
    uint24 fee,
    uint32 oracleSeconds,
    uint256 lowerLimitInTokenB,
    uint256 upperLimitInTokenB
  ) external returns (address) {
    IRangePool.DeploymentParameters memory params = IRangePool.DeploymentParameters({
      uniswapFactory: uniswapFactory,
      uniswapRouter: uniswapRouter,
      positionManager: positionManager,
      tokenA: tokenA,
      tokenB: tokenB,
      fee: fee,
      oracleSeconds: oracleSeconds,
      lowerLimitInTokenB: lowerLimitInTokenB,
      upperLimitInTokenB: upperLimitInTokenB
    });

    RangePool rangePool = new RangePool(params);
    rangePool.transferOwnership(msg.sender);

    emit RangePoolDeployed(msg.sender, address(rangePool));

    return address(rangePool);
  }
}
