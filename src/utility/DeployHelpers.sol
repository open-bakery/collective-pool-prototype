// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

import '@uniswap/v3-core/contracts/UniswapV3Factory.sol';
import '@uniswap/v3-periphery/contracts/SwapRouter.sol' as SR;
import '@uniswap/v3-periphery/contracts/NonfungiblePositionManager.sol' as NPM;
import '@uniswap/v3-periphery/contracts/NonfungibleTokenPositionDescriptor.sol';

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';

import '../RangePool.sol';
import '../RangePoolFactory.sol';
import '../Lens.sol';

import './Token.sol';
import './DevConstants.sol';

pragma abicoder v2;

contract DeployHelpers is DevConstants {
  struct PoolProps {
    address tokenA;
    address tokenB;
    uint24 fee;
  }

  struct Tokens {
    address weth;
    address dai;
    address usdc;
    //    address gmx;
  }

  Tokens tokens;
  IUniswapV3Factory factory;
  INonfungiblePositionManager positionManager;
  ISwapRouter router;

  RangePoolFactory rpFactory;
  Lens lens;

  mapping(uint24 => int24) public TICK_SPACING;

  mapping(uint256 => PoolProps) public poolProps;

  function initDeployHelpers() public {
    TICK_SPACING[FEE_0_05] = TICK_SPACING_0_05;
    TICK_SPACING[FEE_0_30] = TICK_SPACING_0_30;
    TICK_SPACING[FEE_1_00] = TICK_SPACING_1_00;
  }

  function initPoolProps() public {
    poolProps[1] = PoolProps({ tokenA: tokens.weth, tokenB: tokens.dai, fee: FEE_0_30 });
    poolProps[2] = PoolProps({ tokenA: tokens.weth, tokenB: tokens.dai, fee: FEE_1_00 });
    //    poolProps[3] = PoolProps({ tokenA: tokens.usdc, tokenB: tokens.dai, fee: FEE_0_05 });
  }

  function deployAndDistributeTokens() internal {
    tokens.weth = deployAndDistributeToken('WETH', 18);
    tokens.dai = deployAndDistributeToken('DAI', 18);
    //    tokens.usdc = deployAndDistributeToken('USDC', 6);
    //    tokens.gmx = deployAndDistributeToken('GMX');
  }

  function deployAndDistributeToken(string memory symbol, uint8 decimals) internal returns (address) {
    Token t = new Token(symbol, symbol, decimals, a(1_000_000, decimals));
    distributeToken(t);
    return address(t);
  }

  function distributeToken(Token t) private {
    t.transfer(ALICE, a(10_000, t.decimals()));
    t.transfer(BOB, a(10_000, t.decimals()));
    t.transfer(CHARLIE, a(10_000, t.decimals()));
  }

  function deployUniswapBase() public {
    require(tokens.weth != address(0), 'WETH needs to be deployed');
    console.log('deployUniswapBase msg.sender', msg.sender);

    factory = new UniswapV3Factory();
    NonfungibleTokenPositionDescriptor tokenPositionDescriptor = new NonfungibleTokenPositionDescriptor(
      tokens.weth,
      'ETH'
    );
    positionManager = new NPM.NonfungiblePositionManager(
      address(factory),
      tokens.weth,
      address(tokenPositionDescriptor)
    );
    router = new SR.SwapRouter(address(factory), tokens.weth);
  }

  function deployOurBase() public {
    lens = new Lens();
    rpFactory = new RangePoolFactory(address(factory), address(router), address(positionManager));
  }

  function createUniswapPool(
    PoolProps memory props,
    uint256 amountA,
    uint256 amountB,
    uint256 initPrice
  ) public returns (IUniswapV3Pool) {
    // not sure where it's expected to be normalized and where not, so let's just do it ourselves
    (Token token0, Token token1) = props.tokenA < props.tokenB
      ? (Token(props.tokenA), Token(props.tokenB))
      : (Token(props.tokenB), Token(props.tokenA));

    // create
    IUniswapV3Pool pool = IUniswapV3Pool(factory.createPool(address(token0), address(token1), props.fee));

    // approve
    Token(props.tokenA).approve(address(pool), maxAllowance);
    Token(props.tokenB).approve(address(pool), maxAllowance);
    Token(props.tokenA).approve(address(positionManager), maxAllowance);
    Token(props.tokenB).approve(address(positionManager), maxAllowance);

    // intialize
    initPrice = initPrice * 10**(Token(token1).decimals());
    if (address(token0) != props.tokenA) {
      initPrice = 10**(token0.decimals() + token1.decimals()) / initPrice;
    }
    pool.initialize(Conversion.uintToSqrtPriceX96(initPrice, token0.decimals()));

    (int24 tickLower, int24 tickUpper) = Conversion.convertLimitsToTicks(
      (initPrice * 5) / 10,
      initPrice * 2,
      TICK_SPACING[props.fee],
      token0.decimals()
    );
    // mint
    // note: putting the range too large makes the calc in the subgraph index too slow
    positionManager.mint(
      INonfungiblePositionManager.MintParams({
        token0: address(token0),
        token1: address(token1),
        fee: props.fee,
        //        tickLower: MIN_TICK,
        //        tickUpper: MAX_TICK,
        tickLower: tickLower,
        tickUpper: tickUpper,
        amount0Desired: props.tokenA < props.tokenB ? a(amountA, token0.decimals()) : a(amountB, token1.decimals()),
        amount1Desired: props.tokenA < props.tokenB ? a(amountB, token0.decimals()) : a(amountA, token1.decimals()),
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
  ) public returns (RangePool) {
    RangePool rangePool = RangePool(
      rpFactory.deployRangePool(props.tokenA, props.tokenB, props.fee, priceFrom, priceTo)
    );
    Token(props.tokenA).approve(address(rangePool), maxAllowance);
    Token(props.tokenB).approve(address(rangePool), maxAllowance);
    return rangePool;
  }

  function a(uint256 x, uint8 decimals) public pure returns (uint256) {
    return x * 10**decimals;
  }
}
