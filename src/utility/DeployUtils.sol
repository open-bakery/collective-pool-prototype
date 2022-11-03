// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

import 'forge-std/Script.sol';

pragma abicoder v2;

contract DeployUtils is Script {
  string NETWORK = vm.envString('NETWORK');
  string DEPLOY_OUT = vm.envString('DEPLOY_OUT');
  address UNISWAP_V3_FACTORY = vm.envAddress('UNISWAP_V3_FACTORY');
  uint256 DEPLOYER_PRIVATE_KEY = vm.envUint('DEPLOYER_PRIVATE_KEY');

  uint24 FEE_0_05 = 500;
  uint24 FEE_0_30 = 3000;
  uint24 FEE_1_00 = 10000;

  int24 TICK_SPACING_0_05 = 10;
  int24 TICK_SPACING_0_30 = 60;
  int24 TICK_SPACING_1_00 = 200;

  function concat(string memory a, string memory b) public pure returns (string memory) {
    return string(abi.encodePacked(a, b));
  }

  function quote(string memory str) public pure returns (string memory) {
    return concat('"', concat(str, '"'));
  }

  function jsonProp(string memory prop, string memory val) public pure returns (string memory) {
    return concat(quote(prop), concat(': ', quote(val)));
  }

  function outputStart() public {
    vm.writeLine(DEPLOY_OUT, '{');
  }

  function outputEnd() public {
    vm.writeLine(DEPLOY_OUT, '  "finalProp": "Need this so that the last line has no comma"');
    vm.writeLine(DEPLOY_OUT, '}');
  }

  function outputProp(string memory prop, string memory val) public {
    vm.writeLine(DEPLOY_OUT, concat('  ', concat(jsonProp(prop, val), ',')));
  }

  function usdcAmount(uint256 amount) public pure returns (uint256) {
    return amount * 10**6;
  }

  function ethAmount(uint256 amount) public pure returns (uint256) {
    return amount * 10**18;
  }

  function readAddress(string memory name) public returns (address) {
    return vm.parseAddress(vm.readFile(concat('dist/', name)));
  }

  function writeAddress(string memory name, address addr) public {
    vm.writeFile(concat('dist/', name), vm.toString(address(addr)));
  }
}
