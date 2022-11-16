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
  function swap(
    address tokenIn,
    address tokenOut,
    uint24 _fee,
    uint256 amountIn
  ) internal returns (uint256 amountOut) {
    IUniswapV3Pool pool = IUniswapV3Pool(uniFactory.getPool(tokenIn, tokenOut, _fee));

    uint160 limit = pool.token0() == tokenIn ? MIN_SQRT_RATIO : MAX_SQRT_RATIO;

    amountOut = router.exactInputSingle(
      ISwapRouter.ExactInputSingleParams({
        tokenIn: tokenIn,
        tokenOut: tokenOut,
        fee: _fee,
        recipient: address(this),
        deadline: block.timestamp,
        amountIn: amountIn,
        amountOutMinimum: 0,
        sqrtPriceLimitX96: limit
      })
    );
  }

  function run() external {
    vm.startBroadcast();

    initDeployHelpers();
    deployAndDistributeTokens();
    initPoolProps();
    deployUniswapBase();

    // let's deploy a few pools here. we'll need them later
    IUniswapV3Pool pool1 = createUniswapPool(poolProps[1], 100, 150000, 1500);
    //    IUniswapV3Pool pool2 = createUniswapPool(poolProps[1], 100, 150000, 1500);

    // !!! just a dummy transaction to make sure blocks are written properly...
    // seems to be a forge issue. The transactions before only get writtern onchain in the second script???
    ERC20(tokens.dai).transfer(BOB, amount(1));

    vm.stopBroadcast();

    outputProp('startBlock', vm.toString(block.number));
    outputProp('network', NETWORK);

    outputProp('uniFactory', vm.toString(address(factory)));
    outputProp('positionManager', vm.toString(address(positionManager)));

    outputProp('weth', vm.toString(tokens.weth));
    outputProp('dai', vm.toString(tokens.dai));
    outputProp('usdc', vm.toString(tokens.usdc));
    //    outputProp('gmx', vm.toString(tokens.gmx));

    writeAddress('weth', tokens.weth);
    writeAddress('dai', tokens.dai);
    //    writeAddress('usdc', tokens.usdc);

    writeAddress('uniFactory', address(factory));
    writeAddress('router', address(router));
    writeAddress('positionManager', address(positionManager));
  }
}

//Conversion.uintToSqrtPriceX96()
