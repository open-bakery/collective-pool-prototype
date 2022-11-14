// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/console.sol';

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '../src/utility/DeployHelpers.sol';
import '../src/utility/Token.sol';

pragma abicoder v2;

contract RangePoolTest is Test, DeployHelpers {
  function setUp() public {
    console.log('setup msg.sender', msg.sender);

    deployAndDistributeTokens();
    deployUniswapBase();
    deployOurBase();
  }

  function testBaseDeployed() public {
    assertEq(factory.owner(), address(this));
    assertEq(address(rpFactory.uniswapFactory()), address(factory));
    assertEq(address(rpFactory.uniswapRouter()), address(router));
    assertEq(address(rpFactory.positionManager()), address(positionManager));
  }

  function orderTokens(address tokenA, address tokenB) public returns (Token token0, Token token1) {
    return tokenA < tokenB ? (Token(tokenA), Token(tokenB)) : (Token(tokenB), Token(tokenA));
  }

  function testDeployRangePool() public {
    PoolProps memory props = PoolProps({ tokenA: tokens.weth, tokenB: tokens.dai, fee: FEE_0_30 });
    //    (Token token0, Token token1) = orderTokens(tokens.weth, tokens.usdc);
    createUniswapPool(props, 100, 150000, 1500);
    RangePool rp = createRangePool(props, 1000, 2000);

    assertEq(address(rp.rangePoolFactory()), address(rpFactory));
  }

  function testSomethingNice() public {}
}
