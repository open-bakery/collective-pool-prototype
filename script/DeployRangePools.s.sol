// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;
pragma abicoder v2;

import 'forge-std/Script.sol';
import 'forge-std/console.sol';

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

import '../src/RangePool.sol';
import '../src/utility/Token.sol';
import '../src/Lens.sol';

import './DeployCommon.sol';

contract DeployRangePools is DeployCommon {
  RangePoolFactory rpFactory;

  function createRangePool(
    uint256 poolKey,
    uint256 priceFrom,
    uint256 priceTo
  ) private returns (RangePool) {
    PoolProps memory props = poolProps[poolKey];
    RangePool rangePool = RangePool(
      rpFactory.deployRangePool(props.tokenA, props.tokenB, props.fee, priceFrom, priceTo)
    );
    Token(props.tokenA).approve(address(rangePool), maxAllowance);
    Token(props.tokenB).approve(address(rangePool), maxAllowance);
    return rangePool;
  }

  function run() external {
    vm.startBroadcast();

    // the tokens were deployed by the other script. Need to reload them before initPoolProps.
    tokens = Tokens({ weth: readAddress('weth'), usdc: readAddress('usdc') });
    initPoolProps();

    Lens lens = new Lens();
    rpFactory = new RangePoolFactory(
      readAddress('uniFactory'),
      readAddress('router'),
      readAddress('positionManager'),
      tokens.weth,
      address(lens)
    );
    vm.stopBroadcast();

    //    vm.startBroadcast(ALICE_KEY);
    //    RangePool poolA1 = createRangePool(1, amount(900), amount(2200));
    //    poolA1.addLiquidity(amount(5), amount(5), maxSlippage);
    //    vm.stopBroadcast();

    vm.startBroadcast(BOB_KEY);
    console.log('deploying as bob', BOB_KEY);
    console.log('bobs address', vm.addr(BOB_KEY));
    RangePool poolB1 = createRangePool(1, amount(1000), amount(2000));
    poolB1.addLiquidity(amount(5), amount(5), maxSlippage);
    //    RangePool poolB2 = createRangePool(1, amount(1100), amount(1800));
    //    poolB2.addLiquidity(amount(5), amount(5), maxSlippage);
    vm.stopBroadcast();

    outputProp('lens', vm.toString(address(lens)));
    outputProp('factory', vm.toString(address(rpFactory)));
  }
}
