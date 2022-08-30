// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.8.0;

import 'forge-std/Test.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

import '../src/Token.sol';

contract UniswapTest is Test {
  address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  uint256 supply = 100_000 ether;
  Token tokenA;
  Token tokenB;

  IUniswapV3Factory uniFactory;
  ISwapRouter uniRouter;

  // address uniNFPM = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;

  function setUp() public {
    tokenA = new Token('tokenA', 'TKNA', supply);
    tokenB = new Token('tokenB', 'TKNB', supply);
    uniFactory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    uniRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
  }

  function testUni() public {
    assertTrue(tokenA.balanceOf(address(this)) == supply);
    assertTrue(tokenB.balanceOf(address(this)) == supply);
    tokenA.approve(address(uniFactory), type(uint256).max);
    tokenB.approve(address(uniFactory), type(uint256).max);
    address pool = uniFactory.createPool(address(tokenA), address(tokenB), 500);
    console.log(pool);
  }
}
