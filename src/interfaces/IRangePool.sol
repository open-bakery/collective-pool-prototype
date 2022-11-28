// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;

interface IRangePool {
  struct DeploymentParameters {
    address uniswapFactory;
    address uniswapRouter;
    address positionManager;
    address tokenA;
    address tokenB;
    uint24 fee;
    uint32 oracleSeconds;
    uint256 lowerLimitInTokenB;
    uint256 upperLimitInTokenB;
  }
}
