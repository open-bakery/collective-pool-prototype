// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';

import './RangePool.sol';
import './Lens.sol';

contract RangePoolFactory {
  INonfungiblePositionManager public immutable positionManager;
  IUniswapV3Factory public immutable uniFactory;
  ISwapRouter public immutable router;
  address public immutable WETH;
  Lens public immutable lens;

  event RangePoolDeployed(address indexed deployer, address indexed rangePool);

  constructor(
    address _uniFactory,
    address _router,
    address _positionManager,
    address _weth,
    address _lens
  ) {
    positionManager = INonfungiblePositionManager(_positionManager);
    uniFactory = IUniswapV3Factory(_uniFactory);
    router = ISwapRouter(_router);
    WETH = _weth;
    lens = Lens(_lens);
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
