// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

import '../src/utility/DeployUtils.sol';
pragma abicoder v2;

contract DeployCommon is DeployUtils {
  Tokens tokens;

  struct PoolProps {
    address tokenA;
    address tokenB;
    uint24 fee;
  }

  struct Tokens {
    address weth;
    address usdc;
    //    address dai;
    //    address gmx;
  }

  mapping(uint256 => PoolProps) public poolProps;

  function initPoolProps() public {
    poolProps[1] = PoolProps({ tokenA: tokens.weth, tokenB: tokens.usdc, fee: FEE_0_30 });
    poolProps[2] = PoolProps({ tokenA: tokens.weth, tokenB: tokens.usdc, fee: FEE_1_00 });
    //    poolProps[3] = PoolProps({ tokenA: tokens.usdc, tokenB: tokens.dai, fee: FEE_0_05 });
  }
}
