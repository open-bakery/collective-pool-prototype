// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;
pragma abicoder v2;

import 'forge-std/Script.sol';
import 'forge-std/console.sol';

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';

import '../src/utility/Token.sol';
import '../src/libraries/Conversion.sol';
import '../src/utility/DeployHelpers.sol';
import '../src/utility/ScriptHelpers.sol';

contract DeployUniswap is DeployHelpers, ScriptHelpers {
  function run() external {
    vm.startBroadcast();

    deployAndDistributeTokens();
    initPoolProps();
    deployUniswapBase(tokens.weth);
    // let's deploy a few pools here. we'll need them later
    IUniswapV3Pool pool1 = createUniswapPool(poolProps[1], 100, 150000, 1500);
    pool1; // clear warning
    //    IUniswapV3Pool pool2 = createUniswapPool(poolProps[1], 100, 150000, 1500);

    // !!! just a dummy transaction to make sure blocks are written properly...
    // seems to be a forge issue. The transactions before only get written onchain in the second script???
    ERC20(tokens.dai).transfer(BOB, amount(1));
    vm.stopBroadcast();

    //     need a swap to have fees
    //    vm.startBroadcast(ALICE_KEY);
    //    swap(tokens.weth, tokens.dai, poolProps[1].fee, a(1, 18));
    //    vm.stopBroadcast();

    //    vm.startBroadcast(CHARLIE_KEY);
    //    swap(tokens.dai, tokens.weth, poolProps[1].fee, a(500, 18));
    //    vm.stopBroadcast();

    outputProp('startBlock', vm.toString(block.number));
    outputProp('network', NETWORK);

    outputProp('uniFactory', vm.toString(address(uniswapFactory)));
    outputProp('router', vm.toString(address(uniswapRouter)));
    outputProp('positionManager', vm.toString(address(positionManager)));

    outputProp('weth', vm.toString(tokens.weth));
    outputProp('dai', vm.toString(tokens.dai));
    outputProp('usdc', vm.toString(tokens.usdc));

    writeAddress('weth', tokens.weth);
    writeAddress('dai', tokens.dai);
    writeAddress('usdc', tokens.usdc);

    writeAddress('uniswapFactory', address(uniswapFactory));
    writeAddress('router', address(uniswapRouter));
    writeAddress('positionManager', address(positionManager));
  }
}

//Conversion.uintToSqrtPriceX96()
