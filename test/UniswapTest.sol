// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.8.0;
pragma abicoder v2;

import 'forge-std/Test.sol';

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import '@uniswap/v3-core/contracts/libraries/FixedPoint96.sol';

import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol';
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import '@uniswap/v3-periphery/contracts/NonfungiblePositionManager.sol';

import '@uniswap/v3-periphery/contracts/libraries/PositionValue.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import '@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol';
import '@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol';

import '../src/RangePool.sol';

contract UniswapTest is Test, IERC721Receiver {
  using PositionValue for NonfungiblePositionManager;
  using TransferHelper for address;

  IUniswapV3Factory factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);

  NonfungiblePositionManager NFPM =
    NonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
  ISwapRouter router = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

  struct Deposit {
    address owner;
    uint128 liquidity;
    address token0;
    address token1;
  }

  mapping(uint256 => Deposit) deposits;

  function setUp() public {}

  function testArbitrum() public {
    address WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // Token0
    address USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8; // Token1
    uint24 fee = 500;

    RangePool rangePool = new RangePool(WETH, USDC, fee);

    (uint256 price0, uint256 price1) = rangePool.prices();

    uint256 etherAmount = 2 ether;
    uint256 usdAmount = 4000;
    uint256 lowRange = 1000;
    uint256 highRange = 2000;

    usdAmount *= 1e6;
    lowRange *= 1e6;
    highRange *= 1e6;

    (uint256 amount0, uint256 amount1) = rangePool.calculateCorrectDepositRatio(
      etherAmount,
      usdAmount,
      lowRange,
      highRange
    );

    console.log('ETH Deposit: ', amount0);
    console.log('USD Deposit: ', amount1);

    //address pool = 0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443;
    // Test price conversion
    // testUintToSqrtPricex96(pool, 1300000000);

    // IWETH9(WETH).deposit{ value: 1 ether }();
    // swap(WETH, USDC, fee, 1 ether);

    //testOracle(USDC, WETH, fee, 60);
    // console.log(_getPrice(WETH, USDC, fee));
  }

  function testMainnet() public {
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // Token 0
    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // Token 1
    uint24 fee = 500;

    RangePool rangePool = new RangePool(WETH, USDC, fee);

    (uint256 price0, uint256 price1) = rangePool.prices();

    // console.log(price0, price1);
    // console.log(rangePool.price());
    // console.log(rangePool.oraclePrice(60));
    // (uint256 ratio0, uint256 ratio1) = rangePool._getRatioForLiquidity(
    //   500000000000000,
    //   1000000000000000,
    //   10000
    // );
    // console.log('r0: ', ratio0);
    // console.log('r1: ', ratio1);

    //address pool = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;

    // Test Price Conversion
    // testUintToSqrtPricex96(pool, 771118000000000);

    // Test Oracle Functionality
    //testOracle(USDC, WETH, fee, 60);

    // Tests retrieving the prices from both tokens relative to each other.
    // Only to be used for displaying prices.
    //testCheckPrices(USDC, WETH, fee);

    // uint256 lowLimit = uint256(1 ether) / 1300;
    // uint256 highLimit = uint256(1 ether) / 2000;
    // (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
    //
    // (uint256 token0, uint256 token1) = LiquidityAmounts.getAmountsForLiquidity(
    //   sqrtPriceX96,
    //   sqrtPriceX96 / 2,
    //   sqrtPriceX96 * 2,
    //   pool.liquidity()
    // );
    //
    // uint256 reserve1_PB = LiquidityAmounts.getAmount1ForLiquidity(
    //   _uintToX96(1300 * 1e6),
    //   _uintToX96(2000 * 1e6),
    //   pool.liquidity()
    // );
    // console.log((token0 * 1e18) / token1);
    // console.log((token1 * 1e6) / token0);
  }

  function testSimple() public view returns (uint256) {}

  function testUintToSqrtPricex96(IUniswapV3Pool pool, uint256 price) public view {
    (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
    console.log(sqrtPriceX96);
    console.log(_uintToSqrtPriceX96(price, ERC20(pool.token0()).decimals()));
  }

  function testOracle(
    address tokenA,
    address tokenB,
    uint24 fee,
    uint32 numberOfSeconds
  ) public view returns (uint256) {
    IUniswapV3Pool pool = _getPool(tokenA, tokenB, fee);
    uint256 priceToken1RelativeToToken0 = _getUintPriceFromOracle(
      tokenA,
      tokenB,
      fee,
      numberOfSeconds
    );

    uint8 decimalsToken0 = ERC20(pool.token0()).decimals();
    uint8 decimalsToken1 = ERC20(pool.token1()).decimals();

    uint256 priceToken0RelativeToToken1 = 10**(decimalsToken0 + decimalsToken1) /
      priceToken1RelativeToToken0;

    console.log(priceToken1RelativeToToken0);
    console.log(priceToken0RelativeToToken1);
  }

  function testCheckPrices(
    address tokenA,
    address tokenB,
    uint24 fee
  ) public view {
    (address token0, address token1) = _orderTokens(tokenA, tokenB);

    uint8 decimalsToken0 = ERC20(token0).decimals();
    uint8 decimalsToken1 = ERC20(token1).decimals();

    uint256 priceToken1PerToken0 = _getPrice(tokenA, tokenB, fee);
    uint256 priceToken0PerToken1 = 10**(decimalsToken0 + decimalsToken1) / priceToken1PerToken0;

    console.log('priceToken1PerToken0: ', priceToken1PerToken0);
    console.log('priceToken0PerToken1: ', priceToken0PerToken1);
  }

  // This function still needs to be tested.
  function testGetLiquidity() public view {
    uint256 _lowerPrice = 1_000 * 1e6;
    uint256 _upperPrice = 2_000 * 1e6;

    uint160 _lowerSqrtPriceX96 = _uintToSqrtPriceX96(_lowerPrice, 18);
    uint160 _upperSqrtPriceX96 = _uintToSqrtPriceX96(_upperPrice, 18);

    //LiquidityAmounts.getLiquidityForAmount0();
    console.log(_lowerSqrtPriceX96);
  }

  function testMint(
    address tokenA,
    address tokenB,
    uint24 fee,
    uint256 lowerPrice,
    uint256 upperPrice
  ) external {
    uint256 balanceA = ERC20(tokenA).balanceOf(address(this));
    uint256 balanceB = ERC20(tokenB).balanceOf(address(this));

    (uint256 _tokenId, uint128 liquidity, uint256 _amount0, uint256 _amount1) = mintNewPosition(
      tokenA,
      tokenB,
      fee,
      lowerPrice,
      upperPrice,
      balanceA,
      balanceB
    );

    (uint256 amount0, uint256 amount1) = _getPrincipal(_tokenId);

    console.log(amount0);
    console.log(amount1);
  }

  function testSwap() external {}

  function getWeth(address weth, uint256 amount) public payable {
    require(address(this).balance >= amount, 'Not enough Ether in account');
    IWETH9(weth).deposit{ value: amount }();
  }

  function swap(
    address tokenIn,
    address tokenOut,
    uint24 fee,
    uint256 amountIn
  ) public payable returns (uint256 amountOut) {
    // (uint160 sqrtPriceLimitX96, , , , , , ) = pool.slot0();
    // uint256 price = X96ToInt(sqrtPriceLimitX96);
    tokenIn.safeApprove(address(router), amountIn);

    ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
      tokenIn: tokenIn,
      tokenOut: tokenOut,
      fee: fee,
      recipient: address(this),
      deadline: block.timestamp,
      amountIn: amountIn,
      amountOutMinimum: 0,
      sqrtPriceLimitX96: 0
    });

    amountOut = router.exactInputSingle(params);
  }

  function mintNewPosition(
    address token0,
    address token1,
    uint24 poolFee,
    uint256 lowerPrice,
    uint256 upperPrice,
    uint256 amount0Out,
    uint256 amount1Out
  )
    public
    returns (
      uint256 tokenId,
      uint128 liquidity,
      uint256 amount0,
      uint256 amount1
    )
  {
    require(lowerPrice != upperPrice, 'Uniswap Tests: Liquidity must be provided within a range.');

    (int24 tickL, int24 tickU) = _returnRangeInTicks(
      address(_getPool(token0, token1, poolFee)),
      lowerPrice,
      upperPrice
    );

    token0.safeApprove(address(NFPM), amount0Out);
    token1.safeApprove(address(NFPM), amount1Out);

    INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
      token0: token0,
      token1: token1,
      fee: poolFee,
      tickLower: tickL, //Ticker needs to exist (right spacing) and be initisalized
      tickUpper: tickU,
      amount0Desired: amount0Out,
      amount1Desired: amount1Out,
      amount0Min: 0,
      amount1Min: 0,
      recipient: address(this),
      deadline: block.timestamp
    });

    (tokenId, liquidity, amount0, amount1) = NFPM.mint(params);
  }

  function onERC721Received(
    address operator,
    address from,
    uint256 tokenId,
    bytes calldata data
  ) external override returns (bytes4) {
    // get position information
    _createDeposit(operator, tokenId);
    return this.onERC721Received.selector;
  }

  function _orderTokens(address tokenA, address tokenB)
    internal
    pure
    returns (address token0, address token1)
  {
    require(tokenA != tokenB);
    (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
  }

  function _getUintPriceFromOracle(
    address _tokenA,
    address _tokenB,
    uint24 _poolFee,
    uint32 _numberOfSeconds
  ) internal view returns (uint256) {
    address poolAddress = address(_getPool(_tokenA, _tokenB, _poolFee));

    (int24 arithmeticMeanTick, ) = OracleLibrary.consult(poolAddress, _numberOfSeconds);
    uint160 sqrtPricex96 = TickMath.getSqrtRatioAtTick(arithmeticMeanTick);
    uint256 price = _sqrtPriceX96ToUint(
      sqrtPricex96,
      ERC20(IUniswapV3Pool(poolAddress).token0()).decimals()
    );
    return price;
  }

  function _returnRangeInTicks(
    address pool,
    uint256 lowPrice,
    uint256 upperPrice
  ) internal view returns (int24 lowerTick, int24 upperTick) {
    int24 tickSpacing = IUniswapV3Pool(pool).tickSpacing();

    int24 tickL = _getTickNumber(
      lowPrice,
      ERC20(IUniswapV3Pool(pool).token0()).decimals(),
      tickSpacing
    );
    int24 tickU = _getTickNumber(
      upperPrice,
      ERC20(IUniswapV3Pool(pool).token0()).decimals(),
      tickSpacing
    );
    (lowerTick, upperTick) = _orderTick(tickL, tickU);
  }

  function _orderTick(int24 tick0, int24 tick1)
    internal
    pure
    returns (int24 tickLower, int24 tickUpper)
  {
    if (tick1 < tick0) {
      tickLower = tick1;
      tickUpper = tick0;
    } else {
      tickLower = tick0;
      tickUpper = tick1;
    }
  }

  function _roundTick(int24 tick, int24 tickSpacing) internal pure returns (int24) {
    return (tick / tickSpacing) * tickSpacing;
  }

  function _getTickNumber(
    uint256 price,
    uint256 decimalsToken0,
    int24 tickSpacing
  ) internal pure returns (int24) {
    int24 tick = TickMath.getTickAtSqrtRatio(_uintToSqrtPriceX96(price, decimalsToken0));
    int24 validTick = _roundTick(tick, tickSpacing);
    return validTick;
  }

  function _createDeposit(address owner, uint256 tokenId) internal {
    (, , address token0, address token1, , , , uint128 liquidity, , , , ) = NFPM.positions(tokenId);

    // set the owner and data for position
    // operator is msg.sender
    deposits[tokenId] = Deposit({
      owner: owner,
      liquidity: liquidity,
      token0: token0,
      token1: token1
    });
  }

  function _getPrice(
    address tokenA,
    address tokenB,
    uint24 fee
  ) internal view returns (uint256) {
    IUniswapV3Pool pool = IUniswapV3Pool(factory.getPool(tokenA, tokenB, fee));
    (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
    return _sqrtPriceX96ToUint(sqrtPriceX96, ERC20(pool.token0()).decimals());
  }

  function _sqrtPriceX96ToUint(uint160 sqrtPriceX96, uint8 decimalsToken0)
    internal
    pure
    returns (uint256)
  {
    uint256 a = uint256(sqrtPriceX96) * uint256(sqrtPriceX96) * 10**decimalsToken0;
    uint256 b = (96 * 2);
    return a >> b;
  }

  function _uintToSqrtPriceX96(uint256 priceToken1, uint256 decimalsToken0)
    internal
    pure
    returns (uint160)
  {
    uint256 ratioX192 = (priceToken1 << 192) / (10**decimalsToken0);
    return uint160(_sqrt(ratioX192));
  }

  // Get fees from a specific position.
  function _getFees(uint256 _tokenId) internal view returns (uint256 amount0, uint256 amount1) {
    (amount0, amount1) = NFPM.fees(_tokenId);
  }

  // Get principal from a specific position.
  function _getPrincipal(uint256 _tokenId)
    internal
    view
    returns (uint256 amount0, uint256 amount1)
  {
    (, , address token0, address token1, uint24 fee, , , , , , , ) = NFPM.positions(_tokenId);
    IUniswapV3Pool pool = _getPool(token0, token1, fee);
    (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
    (amount0, amount1) = NFPM.principal(_tokenId, sqrtPriceX96);
  }

  function _getPool(
    address tokenA,
    address tokenB,
    uint24 fee
  ) internal view returns (IUniswapV3Pool) {
    return IUniswapV3Pool(_getPoolAddress(tokenA, tokenB, fee, address(factory)));
  }

  function _getPoolAddress(
    address _tokenA,
    address _tokenB,
    uint24 _fee,
    address _factory
  ) internal pure returns (address) {
    return PoolAddress.computeAddress(_factory, PoolAddress.getPoolKey(_tokenA, _tokenB, _fee));
  }

  function _sqrt(uint256 x) internal pure returns (uint256 y) {
    uint256 z = (x + 1) / 2;
    y = x;
    while (z < y) {
      y = z;
      z = (x / z + z) / 2;
    }
  }
}
