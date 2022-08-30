// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.14;

import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import '@uniswap/v3-periphery/contracts/base/LiquidityManagement.sol';

//Contract responsible for creating new pools.
contract Pool is IERC721Receiver {
  address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
  address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address public constant _WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  uint24 public constant poolFee = 3000;

  INonfungiblePositionManager public immutable nonfungiblePositionManager;

  struct Deposit {
    address owner;
    uint128 liquidity;
    address token0;
    address token1;
  }

  mapping(uint256 => Deposit) public deposits;

  constructor(INonfungiblePositionManager _nonfungiblePositionManager) {
    nonfungiblePositionManager = _nonfungiblePositionManager;
  }

  function onERC721Received(
    address operator,
    address from,
    uint256 tokenId,
    bytes calldata data
  ) external override returns (bytes4) {}
}
