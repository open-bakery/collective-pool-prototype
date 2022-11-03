// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;
pragma abicoder v2;

import 'forge-std/Script.sol';

import '@uniswap/v3-core/contracts/UniswapV3Factory.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-periphery/contracts/NonfungiblePositionManager.sol' as NMP;
import '@uniswap/v3-periphery/contracts/NonfungibleTokenPositionDescriptor.sol';

import '../src/utility/DeployUtils.sol';
import '../src/utility/Token.sol';
import '../src/Lens.sol';

import 'forge-std/console.sol';

contract Deploy is DeployUtils {
  function run() external {
    vm.startBroadcast();

    UniswapV3Factory uniFactory = new UniswapV3Factory();

    // we want to have a few erc20 tokens for sure
    address weth = address(new Token('WETH', 'WETH', 18, ethAmount(1_000_000)));
    address usdc = address(new Token('USD Coin', 'USDC', 6, usdcAmount(1_000_000)));
    address dai = address(new Token('DAI', 'DAI', 18, usdcAmount(1_000_000)));
    address gmx = address(new Token('GMX', 'GMX', 18, ethAmount(1_000_000)));

    // let's deploy a few pools here. we'll need them later
    uniFactory.createPool(weth, usdc, FEE_0_30);
    uniFactory.createPool(weth, usdc, FEE_1_00);
    uniFactory.createPool(usdc, dai, FEE_0_05);
    uniFactory.createPool(weth, gmx, FEE_0_30);
    uniFactory.createPool(gmx, dai, FEE_0_30);

    // uniswap stuff
    NonfungibleTokenPositionDescriptor tokenPositionDescriptor = new NonfungibleTokenPositionDescriptor(weth, 'ETH');
    NMP.NonfungiblePositionManager positionManager = new NMP.NonfungiblePositionManager(
      address(uniFactory),
      weth,
      address(tokenPositionDescriptor)
    );

    // our stuff
    Lens lens = new Lens();
    RangePoolFactory factory = new RangePoolFactory(address(uniFactory), address(positionManager), weth, address(lens));

    address pool1 = factory.deployRangePool(weth, usdc, FEE_0_30, usdcAmount(1000), usdcAmount(2000));
    address pool2 = factory.deployRangePool(weth, usdc, FEE_1_00, usdcAmount(500), usdcAmount(4000));
    factory.deployRangePool(dai, usdc, FEE_0_05, usdcAmount(9) / 10, usdcAmount(11) / 10);
    factory.deployRangePool(weth, gmx, FEE_0_30, ethAmount(10), ethAmount(100));
    factory.deployRangePool(gmx, dai, FEE_0_30, ethAmount(20), ethAmount(80));

    outputStart();
    outputProp('startBlock', vm.toString(block.number));
    outputProp('network', NETWORK);

    outputProp('uniFactory', vm.toString(address(uniFactory)));
    outputProp('tokenPositionDescriptor', vm.toString(address(tokenPositionDescriptor)));
    outputProp('positionManager', vm.toString(address(positionManager)));

    outputProp('weth', vm.toString(weth));
    outputProp('usdc', vm.toString(usdc));
    outputProp('gmx', vm.toString(gmx));
    outputProp('dai', vm.toString(dai));
    outputProp('lens', vm.toString(address(lens)));
    outputProp('factory', vm.toString(address(factory)));
    outputProp('pool1', vm.toString(pool1));
    outputProp('pool2', vm.toString(pool2));
    outputEnd();

    vm.stopBroadcast();
  }
}
