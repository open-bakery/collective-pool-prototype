// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;
pragma abicoder v2;

import 'forge-std/Script.sol';
import 'forge-std/console2.sol';

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import '../src/RangePoolFactory.sol';
import '../src/RangePool.sol';
import '../src/Lens.sol';

contract Deploy is Script {
  address uniFactory = vm.envAddress('UNISWAP_V3_FACTORY');
  address positionManager = vm.envAddress('UNISWAP_V3_NFPM');

  address WETH = vm.envAddress('ARB_WETH');
  address USDC = vm.envAddress('ARB_USDC');
  string DEPLOY_OUT = vm.envString('DEPLOY_OUT');

  uint24 FEE0_05 = 500;
  uint24 FEE0_30 = 3000;
  uint24 FEE1_00 = 10000;

  function setUp() public {}

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

  function usdcAmount(uint256 amount) private pure returns (uint256) {
    return amount * 10**6;
  }

  function ethAmount(uint256 amount) private pure returns (uint256) {
    return amount * 10**18;
  }

  function approvePool(address token, RangePool pool) private {
    ERC20(token).approve(address(pool), type(uint256).max);
  }

  function run() external {
    vm.startBroadcast();
    outputStart();

    RangePoolFactory factory = new RangePoolFactory(uniFactory, positionManager, WETH);
    outputProp('factory', vm.toString(address(factory)));
    outputProp('lens', vm.toString(address(new Lens())));

    address pool1 = factory.deployRangePool(WETH, USDC, FEE0_30, usdcAmount(1000), usdcAmount(2000));
    outputProp('pool1', vm.toString(pool1));

    address pool2 = factory.deployRangePool(WETH, USDC, FEE0_30, usdcAmount(500), usdcAmount(4000));
    outputProp('pool2', vm.toString(pool2));
    outputProp('startBlock', vm.toString(block.number));

    outputEnd();
    vm.stopBroadcast();
  }
}
