// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;

import '@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol';
import './Stack.sol';

contract EthStacker is Stack {
  using SafeERC20 for ERC20;
  using SafeMath for uint256;

  address weth;

  constructor(address weth_) {
    weth = weth_;
  }

  function collectAndSplit(RangePool rangePool) external {}

  function stackEth(RangePool rangePool, uint16 slippage) external returns (uint256 amountStacked) {
    amountStacked = _stack(rangePool, weth, slippage);
  }
}
