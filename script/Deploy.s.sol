// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;
pragma abicoder v2;

import 'forge-std/Script.sol';

import '@uniswap/v3-core/contracts/UniswapV3Factory.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import '@uniswap/v3-periphery/contracts/SwapRouter.sol' as SR;
import '@uniswap/v3-periphery/contracts/NonfungiblePositionManager.sol' as NPM;
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import '@uniswap/v3-periphery/contracts/NonfungibleTokenPositionDescriptor.sol';
import '@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol';

import '../src/utility/DeployUtils.sol';
import '../src/utility/Token.sol';
import '../src/Lens.sol';
import '../src/libraries/Conversion.sol';

import 'forge-std/console.sol';

contract Deploy is DeployUtils {
  UniswapV3Factory uniFactory;

  struct Tokens {
    address weth;
    address usdc;
    address dai;
    address gmx;
  }

  struct PoolProps {
    address tokenA;
    address tokenB;
    uint24 fee;
  }

  struct Pools {
    address pool1;
  }

  uint8 decimals = 18;
  uint16 maxSlippage = 100_00;
  uint256 maxAllowance = MAX_INT;

  RangePoolFactory rpFactory;
  Tokens tokens;
  NPM.NonfungiblePositionManager positionManager;

  function createAndDistributeTokens() internal {
    tokens.weth = createAndDistributeToken('WETH');
    tokens.usdc = createAndDistributeToken('USDC');
    tokens.dai = createAndDistributeToken('DAI');
    tokens.gmx = createAndDistributeToken('GMX');
    console.log('weth', tokens.weth);
    console.log('usdc', tokens.usdc);
    console.log('dai', tokens.dai);
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

  function createUniPool(PoolProps memory props, uint256 initPrice) private returns (IUniswapV3Pool) {
    // not sure where it's expected to be normalized and where not, so let's just do it ourselves
    (address token0, address token1) = props.tokenA < props.tokenB
      ? (props.tokenA, props.tokenB)
      : (props.tokenB, props.tokenA);

    // create
    IUniswapV3Pool pool = IUniswapV3Pool(uniFactory.createPool(token0, token1, props.fee));
    console.log('pool address', address(pool));

    // approve
    Token(props.tokenA).approve(address(pool), maxAllowance);
    Token(props.tokenB).approve(address(pool), maxAllowance);
    Token(props.tokenA).approve(address(positionManager), maxAllowance);
    Token(props.tokenB).approve(address(positionManager), maxAllowance);

    // intialize
    uint256 actualInitPrice = token0 == props.tokenA ? initPrice : (10**decimals * 10**decimals) / initPrice;
    pool.initialize(Conversion.uintToSqrtPriceX96(actualInitPrice, decimals));

    // mint
    positionManager.mint(
      INonfungiblePositionManager.MintParams({
        token0: token0,
        token1: token1,
        fee: props.fee,
        tickLower: MIN_TICK,
        tickUpper: MAX_TICK,
        amount0Desired: amount(10),
        amount1Desired: amount(10),
        amount0Min: 0,
        amount1Min: 0,
        recipient: msg.sender,
        deadline: block.timestamp + 1000
      })
    );
    return pool;
  }

  function createRangePool(
    PoolProps memory props,
    uint256 priceFrom,
    uint256 priceTo
  ) private returns (RangePool) {
    RangePool rangePool = RangePool(
      rpFactory.deployRangePool(props.tokenA, props.tokenB, props.fee, priceFrom, priceTo)
    );
    Token(props.tokenA).approve(address(rangePool), maxAllowance);
    Token(props.tokenB).approve(address(rangePool), maxAllowance);
    //    rangePool.addLiquidity(amount(10), amount(10), maxSlippage); // this breaks?
    return rangePool;
  }

  function run() external {
    vm.startBroadcast();

    createAndDistributeTokens();

    uniFactory = new UniswapV3Factory();
    console.log('uni factory', address(uniFactory));

    PoolProps memory poolProps1 = PoolProps({ tokenA: tokens.weth, tokenB: tokens.usdc, fee: FEE_0_30 });
    PoolProps memory poolProps2 = PoolProps({ tokenA: tokens.weth, tokenB: tokens.usdc, fee: FEE_1_00 });
    PoolProps memory poolProps3 = PoolProps({ tokenA: tokens.usdc, tokenB: tokens.dai, fee: FEE_0_05 });

    // uniswap periphery
    NonfungibleTokenPositionDescriptor tokenPositionDescriptor = new NonfungibleTokenPositionDescriptor(
      tokens.weth,
      'ETH'
    );
    positionManager = new NPM.NonfungiblePositionManager(
      address(uniFactory),
      tokens.weth,
      address(tokenPositionDescriptor)
    );
    SR.SwapRouter router = new SR.SwapRouter(address(uniFactory), tokens.weth);

    // let's deploy a few pools here. we'll need them later
    IUniswapV3Pool uniPool1 = createUniPool(poolProps1, 1500);
    IUniswapV3Pool uniPool2 = createUniPool(poolProps2, 1600);
    //    console.log('-------');
    //    console.log('deploying uni pool', '3');
    //    IUniswapV3Pool uniPool3 = createUniPool(poolProps3, 1);
    //    uniFactory.createPool(weth, gmx, FEE_0_30);
    //    uniFactory.createPool(gmx, dai, FEE_0_30);

    // our stuff
    Lens lens = new Lens();
    rpFactory = new RangePoolFactory(
      address(uniFactory),
      address(router),
      address(positionManager),
      tokens.weth,
      address(lens)
    );

    // for oracle to work (see RangePool.oracleSeconds)
    //    vm.warp(block.timestamp + 60);

    RangePool pool1 = createRangePool(poolProps1, amount(1000), amount(2000));
    RangePool pool2 = createRangePool(poolProps2, amount(500), amount(4000));
    RangePool pool3 = createRangePool(poolProps1, amount(800), amount(2400));
    //    RangePool pool3 = createRangePool(poolProps3, amount(9) / 10, amount(11) / 1);

    //    rpFactory.deployRangePool(weth, gmx, FEE_0_30, ethAmount(10), ethAmount(100));
    //    rpFactory.deployRangePool(gmx, dai, FEE_0_30, ethAmount(20), ethAmount(80));

    outputStart();
    outputProp('startBlock', vm.toString(block.number));
    outputProp('network', NETWORK);

    outputProp('uniFactory', vm.toString(address(uniFactory)));
    outputProp('tokenPositionDescriptor', vm.toString(address(tokenPositionDescriptor)));
    outputProp('positionManager', vm.toString(address(positionManager)));

    outputProp('weth', vm.toString(tokens.weth));
    outputProp('usdc', vm.toString(tokens.usdc));
    outputProp('gmx', vm.toString(tokens.gmx));
    outputProp('dai', vm.toString(tokens.dai));
    outputProp('lens', vm.toString(address(lens)));
    outputProp('factory', vm.toString(address(rpFactory)));
    outputProp('pool1', vm.toString(address(pool1)));
    outputProp('pool2', vm.toString(address(pool2)));
    outputEnd();

    //    IUniswapV3Pool(uniPool1).swap(msg.sender, true, samount(10), 0, ''); // swap 10 eth to usd

    vm.stopBroadcast();

    //    vm.startBroadcast(ALICE);
    //    Token(weth).approve(address(uniPool1), );
    //    vm.stopBroadcast();
  }
}

//Conversion.uintToSqrtPriceX96()
