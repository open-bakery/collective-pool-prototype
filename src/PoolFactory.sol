// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.14;


import "@openzeppelin/contracts/access/Ownable.sol";
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import '@uniswap/v3-periphery/contracts/base/LiquidityManagement.sol';
//Contract responsible for creating new pools.

contract PoolFactory is Ownable {

  constructor() {

  }

  function addPool() external onlyOwner {
    // Adds new pool to the protocol
  }

}
