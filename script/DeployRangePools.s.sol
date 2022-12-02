// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;
pragma abicoder v2;

import 'forge-std/Script.sol';
import 'forge-std/console.sol';

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

import '../src/RangePool.sol';
import '../src/utility/Token.sol';
import '../src/Lens.sol';

import '../src/utility/DeployHelpers.sol';
import '../src/utility/ScriptHelpers.sol';

contract DeployRangePools is DeployHelpers, ScriptHelpers {
  function run() external {
    // the tokens were deployed by the other script. Need to reload them before initPoolProps.
    tokens = Tokens({ weth: readAddress('weth'), dai: readAddress('dai'), usdc: readAddress('usdc') });
    uniswapFactory = IUniswapV3Factory(readAddress('uniswapFactory'));
    uniswapRouter = ISwapRouter(readAddress('uniswapRouter'));
    positionManager = INonfungiblePositionManager(readAddress('positionManager'));

    vm.startBroadcast();
    initPoolProps();
    deployOurBase();
    vm.stopBroadcast();

    /*
    vm.startBroadcast(ALICE_KEY);
    RangePool poolA1 = createRangePool(1, amount(900), amount(2200));
    poolA1.addLiquidity(amount(5), amount(5), maxSlippage);
    vm.stopBroadcast();
*/

    vm.startBroadcast(BOB_KEY);
    console.log('deploying as bob', BOB_KEY);
    console.log('bobs address', vm.addr(BOB_KEY));
    RangePool poolB1 = createRangePool(poolProps[1], amount(1000), amount(2000));
    poolB1.addLiquidity(amount(5), amount(5), maxSlippage);
    /*
    RangePool poolB2 = createRangePool(1, amount(1100), amount(1800));
    poolB2.addLiquidity(amount(5), amount(5), maxSlippage);
*/
    vm.stopBroadcast();

    vm.startBroadcast(ALICE_KEY);
    Token(tokens.weth).approve(address(uniswapRouter), maxAllowance);
    Token(tokens.dai).approve(address(uniswapRouter), maxAllowance);
    swap(tokens.weth, tokens.dai, poolProps[1].fee, a(1, 18));
    vm.stopBroadcast();

    outputProp('lens', vm.toString(address(lens)));
    outputProp('rangePoolFactory', vm.toString(address(rangePoolFactory)));
    writeAddress('rangePoolFactory', address(rangePoolFactory));
  }
}
