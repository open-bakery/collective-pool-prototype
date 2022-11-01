// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;
pragma abicoder v2;

import 'forge-std/Script.sol';
import 'forge-std/console2.sol';

import '@uniswap/v3-core/contracts/UniswapV3Factory.sol';
import '@uniswap/v3-periphery/contracts/NonfungiblePositionManager.sol';
import '@uniswap/v3-periphery/contracts/NonfungibleTokenPositionDescriptor.sol';

import '../src/RangePoolFactory.sol';
import '../src/RangePool.sol';
import '../src/Lens.sol';
import '../src/utility/Token.sol';

contract Deploy is Script {
  //  address uniFactory = vm.envAddress('UNISWAP_V3_FACTORY');
  //  address positionManager = vm.envAddress('UNISWAP_V3_NFPM');
  //  address WETH = vm.envAddress('WETH');
  //  address USDC = vm.envAddress('USDC');

  Token WETH;
  Token USDC;
  Token GMX;
  UniswapV3Factory uniFactory;
  NonfungiblePositionManager positionManager;
  NonfungibleTokenPositionDescriptor tokenPositionDescriptor;

  UniswapV3Pool poolWethUsdc030;

  string NETWORK = vm.envString('NETWORK');
  string DEPLOY_OUT = vm.envString('DEPLOY_OUT');

  uint24 FEE0_05 = 500;
  uint24 FEE0_30 = 3000;
  uint24 FEE1_00 = 10000;

  int24 TICK_SPACING_0_05 = 10;
  int24 TICK_SPACING_0_30 = 60;
  int24 TICK_SPACING_1_00 = 200;

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

  function deployTokens() private {
    WETH = new Token('WETH', 'WETH', 18, 1_000_000 * 10**18);
    USDC = new Token('USD Coin', 'USDC', 6, 1_000_000 * 10**6);
    GMX = new Token('GMX', 'GMX', 18, 1_000_000 * 10**18);
    outputProp('weth', vm.toString(address(WETH)));
    outputProp('usdc', vm.toString(address(USDC)));
    outputProp('gmx', vm.toString(address(GMX)));
  }

  function deployUniswap() private {
    uniFactory = new UniswapV3Factory();
    tokenPositionDescriptor = new NonfungibleTokenPositionDescriptor(address(WETH), vm.parseBytes('ETH'));
    positionManager = new NonfungiblePositionManager(
      address(uniFactory),
      address(WETH),
      address(tokenPositionDescriptor)
    );

    outputProp('uniFactory', vm.toString(address(uniFactory)));
    outputProp('tokenPositionDescriptor', vm.toString(address(tokenPositionDescriptor)));
    outputProp('positionManager', vm.toString(address(positionManager)));

    poolWethUsdc030 = uniFactory.createPool(address(WETH), address(USDC), FEE0_30);
    poolWethGmx030 = uniFactory.createPool(address(WETH), address(USDC), FEE0_30);
  }

  function run() external {
    vm.startBroadcast();
    outputStart();

    deployTokens();
    deployUniswap();

    Lens lens = new Lens();
    outputProp('lens', vm.toString(address(lens)));

    RangePoolFactory factory = new RangePoolFactory(uniFactory, positionManager, WETH, address(lens));
    outputProp('factory', vm.toString(address(factory)));

    address pool1 = factory.deployRangePool(WETH, USDC, FEE0_30, usdcAmount(1000), usdcAmount(2000));
    outputProp('pool1', vm.toString(pool1));

    address pool2 = factory.deployRangePool(WETH, USDC, FEE0_30, usdcAmount(500), usdcAmount(4000));
    outputProp('pool2', vm.toString(pool2));
    outputProp('startBlock', vm.toString(block.number));
    outputProp('network', NETWORK);

    outputEnd();
    vm.stopBroadcast();
  }
}
