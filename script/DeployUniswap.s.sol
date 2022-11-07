// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;
pragma abicoder v2;

import 'forge-std/Script.sol';
import 'forge-std/console.sol';

import '@uniswap/v3-core/contracts/UniswapV3Factory.sol';
import '@uniswap/v3-core/contracts/libraries/Oracle.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import '@uniswap/v3-periphery/contracts/SwapRouter.sol' as SR;
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/NonfungiblePositionManager.sol' as NPM;
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import '@uniswap/v3-periphery/contracts/NonfungibleTokenPositionDescriptor.sol';
import '@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol';

import '../src/utility/Token.sol';
import '../src/libraries/Conversion.sol';
import './DeployCommon.sol';

contract DeployUniswap is DeployCommon {
  UniswapV3Factory uniFactory;
  ISwapRouter router;
  INonfungiblePositionManager positionManager;

  function createAndDistributeTokens() internal {
    tokens.weth = createAndDistributeToken('WETH');
    tokens.usdc = createAndDistributeToken('USDC');
    //    tokens.dai = createAndDistributeToken('DAI');
    //    tokens.gmx = createAndDistributeToken('GMX');
  }

  function createAndDistributeToken(string memory symbol) internal returns (address) {
    Token t = new Token(symbol, symbol, decimals, amount(1_000_000));
    distributeToken(t);
    return address(t);
  }

  function distributeToken(Token t) private {
    t.transfer(ALICE, amount(10_000));
    t.transfer(BOB, amount(10_000));
    t.transfer(CHARLIE, amount(10_000));
  }

  function swap(
    address tokenIn,
    address tokenOut,
    uint24 _fee,
    uint256 amountIn
  ) internal returns (uint256 amountOut) {
    IUniswapV3Pool pool = IUniswapV3Pool(uniFactory.getPool(tokenIn, tokenOut, _fee));
    (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(pool).slot0();

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

  function createUniPool(
    PoolProps memory props,
    uint256 amountA,
    uint256 amountB,
    uint256 initPrice
  ) private returns (IUniswapV3Pool) {
    // not sure where it's expected to be normalized and where not, so let's just do it ourselves
    (address token0, address token1) = props.tokenA < props.tokenB
      ? (props.tokenA, props.tokenB)
      : (props.tokenB, props.tokenA);

    // create
    IUniswapV3Pool pool = IUniswapV3Pool(uniFactory.createPool(token0, token1, props.fee));

    // approve
    Token(props.tokenA).approve(address(pool), maxAllowance);
    Token(props.tokenB).approve(address(pool), maxAllowance);
    Token(props.tokenA).approve(address(positionManager), maxAllowance);
    Token(props.tokenB).approve(address(positionManager), maxAllowance);

    // intialize
    if (token0 != props.tokenA) {
      initPrice = 10**decimals / initPrice;
    }
    pool.initialize(Conversion.uintToSqrtPriceX96(initPrice, decimals));

    (int24 tickLower, int24 tickUpper) = Conversion.convertLimitsToTicks(
      (initPrice * 5) / 10,
      initPrice * 2,
      TICK_SPACING[props.fee],
      decimals
    );
    // mint
    // note: putting the range too large makes the calc in the subgraph index too slow
    positionManager.mint(
      INonfungiblePositionManager.MintParams({
        token0: token0,
        token1: token1,
        fee: props.fee,
        //        tickLower: MIN_TICK,
        //        tickUpper: MAX_TICK,
        tickLower: tickLower,
        tickUpper: tickUpper,
        amount0Desired: props.tokenA < props.tokenB ? amount(amountA) : amount(amountB),
        amount1Desired: props.tokenA < props.tokenB ? amount(amountB) : amount(amountA),
        amount0Min: 0,
        amount1Min: 0,
        recipient: msg.sender,
        deadline: block.timestamp + 1000
      })
    );
    return pool;
  }

  function run() external {
    vm.startBroadcast();

    init();
    createAndDistributeTokens();
    initPoolProps();

    uniFactory = new UniswapV3Factory();
    NonfungibleTokenPositionDescriptor tokenPositionDescriptor = new NonfungibleTokenPositionDescriptor(
      tokens.weth,
      'ETH'
    );
    positionManager = new NPM.NonfungiblePositionManager(
      address(uniFactory),
      tokens.weth,
      address(tokenPositionDescriptor)
    );
    router = new SR.SwapRouter(address(uniFactory), tokens.weth);

    // let's deploy a few pools here. we'll need them later
    IUniswapV3Pool pool1 = createUniPool(poolProps[1], 100, 150000, 1500);
    //    swap(poolProps[1].tokenA, poolProps[1].tokenB, poolProps[1].fee, amount(1));
    //    IUniswapV3Pool uniPool2 = createUniPool(poolProps2, 1600);

    //    IUniswapV3Pool uniPool3 = createUniPool(poolProps3, 1);
    //    uniFactory.createPool(weth, gmx, FEE_0_30);
    //    uniFactory.createPool(gmx, dai, FEE_0_30);

    //    rpFactory.deployRangePool(weth, gmx, FEE_0_30, ethAmount(10), ethAmount(100));
    //    rpFactory.deployRangePool(gmx, dai, FEE_0_30, ethAmount(20), ethAmount(80));

    //    vm.stopBroadcast();
    //    vm.startBroadcast(BOB);

    // just a dummy transaction to make sure blocks are written properly...
    // seems to be a forge issue. The transactions before only get writtern onchain in the second script???
    ERC20(tokens.usdc).transfer(BOB, amount(1));

    vm.stopBroadcast();

    outputProp('startBlock', vm.toString(block.number));
    outputProp('network', NETWORK);

    outputProp('uniFactory', vm.toString(address(uniFactory)));
    outputProp('tokenPositionDescriptor', vm.toString(address(tokenPositionDescriptor)));
    outputProp('positionManager', vm.toString(address(positionManager)));

    outputProp('weth', vm.toString(tokens.weth));
    outputProp('usdc', vm.toString(tokens.usdc));
    //    outputProp('gmx', vm.toString(tokens.gmx));
    //    outputProp('dai', vm.toString(tokens.dai));

    writeAddress('weth', tokens.weth);
    writeAddress('usdc', tokens.usdc);

    writeAddress('uniFactory', address(uniFactory));
    writeAddress('router', address(router));
    writeAddress('positionManager', address(positionManager));
  }
}

//Conversion.uintToSqrtPriceX96()
