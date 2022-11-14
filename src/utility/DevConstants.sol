// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

import 'forge-std/Script.sol';

contract DevConstants is Script {
  address ALICE = vm.envAddress('ALICE_ADDRESS');
  address BOB = vm.envAddress('BOB_ADDRESS');
  address CHARLIE = vm.envAddress('CHARLIE_ADDRESS');
  uint256 ALICE_KEY = vm.envUint('ALICE_KEY');
  uint256 BOB_KEY = vm.envUint('BOB_KEY');
  uint256 CHARLIE_KEY = vm.envUint('CHARLIE_KEY');

  uint24 FEE_0_05 = 500;
  uint24 FEE_0_30 = 3000;
  uint24 FEE_1_00 = 10000;

  int24 TICK_SPACING_0_05 = 10;
  int24 TICK_SPACING_0_30 = 60;
  int24 TICK_SPACING_1_00 = 200;

  int24 internal constant MIN_TICK = -886800;
  int24 internal constant MAX_TICK = 886800;

  uint160 internal constant MIN_SQRT_RATIO = 4295128739;
  uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

  uint256 MAX_INT = 2**256 - 1;
  uint16 maxSlippage = 100_00;
  uint256 maxAllowance = MAX_INT;
}
