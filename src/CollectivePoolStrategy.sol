// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

import './RangePoolManager.sol';

contract CollectivePoolStrategy {
  using SafeERC20 for ERC20;
  using SafeMath for uint256;
  struct PositionData {
    uint128 liquidity;
    uint256 claimedFees0;
    uint256 claimedFees1;
    uint256 feeDebt0;
    uint256 feeDebt1;
  }
  uint256 precision = 1 ether;
  uint256 accFeePerLiquidity0;
  uint256 accFeePerLiquidity1;
  // mapping(address => address) public liquitityToken; // liquidityToken[rangePool] = address;
  mapping(address => mapping(address => PositionData)) public position; // position[rangePool][user] = PositionData;
  // function addLiquidity(
  //     RangePool rangePool,
  //     uint256 amount0,
  //     uint256 amount1,
  //     uint16 slippage,
  //     address delegate
  //   )
  //     external
  //     returns (
  //       uint128 liquidityAdded,
  //       uint256 amountAdded0,
  //       uint256 amountAdded1,
  //       uint256 amountRefunded0,
  //       uint256 amountRefunded1
  //     )
  //   {
  //     PositionData storage posData = position[rangePool][msg.sender];
  //     if (posData.liquidity != 0) {
  //       (, , uint256 collectedFees0, uint256 collectedFees1) = collectFees(rangePool, delegate);
  //       if (collectedFees0 + collectedFees1 != 0) {
  //         uint256 feeAmount0 = (posData.liquidity * accFeePerLiquidity0) / precision;
  //         uint256 feeAmount1 = (posData.liquidity * accFeePerLiquidity1) / precision;
  //       }
  //     }
  //     posData.liquidity += liquidityAdded;
  //     _updateAccFeePerLiquidity(rangePool);
  //     posData.feeDebt0 = (posData.liquidity * accFeePerLiquidity0) / precision;
  //     posData.feeDebt1 = (posData.liquidity * accFeePerLiquidity1) / precision;
  //   }
  //   function collectFees(RangePool rangePool) external {
  //     (tokenCollected0, tokenCollected1, collectedFees0, collectedFees1) = rangePool.collectFees();
  //     _updateAccFeePerLiquidity(rangePool, collectedFees0, collectedFees1);
  //   }
  //   function _updateAccFeePerLiquidity(
  //     RangePool rangePool,
  //     uint256 collectedFees0,
  //     uint256 collectedFees1
  //   ) internal {
  //     if (collectedFees0 + collectedFees1 != 0) {
  //       uint256 totalLiquidity = uint256(Helper.positionLiquidity(rangePool.positionManager(), rangePool.tokenId()));
  //       accFeePerLiquidity0 += (collectedFees0 * precision) / totalLiquidity;
  //       accFeePerLiquidity1 += (collectedFees1 * precision) / totalLiquidity;
  //     }
  //   }
}
