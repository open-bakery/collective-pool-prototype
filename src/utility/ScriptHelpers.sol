// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

import 'forge-std/Script.sol';
import './DevConstants.sol';

pragma abicoder v2;

contract ScriptHelpers is DevConstants {
  string NETWORK = vm.envString('NETWORK');
  string DEPLOY_OUT = vm.envString('DEPLOY_OUT');
  address UNISWAP_V3_FACTORY = vm.envAddress('UNISWAP_V3_FACTORY');
  uint256 DEPLOYER_PRIVATE_KEY = vm.envUint('DEPLOYER_PRIVATE_KEY');

  //  address DEPLOYER = vm.envAddress('DEPLOYER_ADDRESS');

  // these are almost the real minimal, but divisible by all tick spacings. uff. this game me some headaches.

  uint8 decimals = 18;

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

  function usdcAmount(uint256 a) public pure returns (uint256) {
    return a * 10**6;
  }

  function ethAmount(uint256 a) public pure returns (uint256) {
    return a * 10**18;
  }

  function amount(uint256 a) public pure returns (uint256) {
    return a * 10**18;
  }

  // signed int version
  function samount(int256 a) public pure returns (int256) {
    return a * 10**18;
  }

  function readAddress(string memory name) public returns (address) {
    return vm.parseAddress(vm.readFile(concat('dist/', name)));
  }

  function writeAddress(string memory name, address addr) public {
    vm.writeFile(concat('dist/', name), vm.toString(address(addr)));
  }
}
