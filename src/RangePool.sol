// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;

import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

import './interfaces/IRangePool.sol';
import './libraries/Helper.sol';

// All prices and ranges in Uniswap are denominated in token1 (y) relative to token0 (x): (y/x as in x*y=k)
//Contract responsible for creating new pools.
contract RangePool is IRangePool, Ownable {
  using SafeERC20 for ERC20;
  using Address for address;
  using SafeMath for uint256;

  address public immutable uniswapFactory;
  address public immutable uniswapRouter;
  INonfungiblePositionManager public immutable positionManager;

  IUniswapV3Pool public pool;

  uint32 public oracleSeconds;
  int24 public lowerTick;
  int24 public upperTick;

  uint256 public tokenId;
  uint256 public totalClaimedFees0;
  uint256 public totalClaimedFees1;

  event PositionMinted(address indexed recipient, uint256 tokenId);
  event LiquidityIncreased(address indexed recipient, uint256 amount0, uint256 amount1, uint128 liquidity);
  event LiquidityDecreased(address indexed recipient, uint256 amount0, uint256 amount1);
  event FeesCollected(
    address indexed recipient,
    address indexed token0,
    address indexed token1,
    uint256 amountCollected0,
    uint256 amountCollected1
  );

  constructor(DeploymentParameters memory params) {
    uniswapFactory = params.uniswapFactory;
    uniswapRouter = params.uniswapRouter;
    positionManager = INonfungiblePositionManager(params.positionManager);

    oracleSeconds = params.oracleSeconds;

    pool = IUniswapV3Pool(Helper.getPoolAddress(params.tokenA, params.tokenB, params.fee, params.uniswapFactory));

    (lowerTick, upperTick) = Helper.validateAndConvertLimits(
      pool,
      params.tokenB,
      params.lowerLimitInTokenB,
      params.upperLimitInTokenB
    );

    ERC20(pool.token0()).safeApprove(address(params.positionManager), type(uint256).max);
    ERC20(pool.token1()).safeApprove(address(params.positionManager), type(uint256).max);
  }

  function addLiquidity(
    uint256 amount0,
    uint256 amount1,
    uint16 slippage
  )
    external
    onlyOwner
    returns (
      uint128 liquidityAdded,
      uint256 amountAdded0,
      uint256 amountAdded1,
      uint256 amountRefunded0,
      uint256 amountRefunded1
    )
  {
    ERC20(pool.token0()).safeTransferFrom(msg.sender, address(this), amount0);
    ERC20(pool.token1()).safeTransferFrom(msg.sender, address(this), amount1);

    (liquidityAdded, amountAdded0, amountAdded1, amountRefunded0, amountRefunded1) = _addLiquidity(
      msg.sender,
      amount0,
      amount1,
      slippage
    );
  }

  function removeLiquidity(uint128 liquidityAmount, uint16 slippage)
    public
    onlyOwner
    returns (uint256 amountRemoved0, uint256 amountRemoved1)
  {
    (amountRemoved0, amountRemoved1) = _decreaseLiquidity(msg.sender, liquidityAmount, slippage);
  }

  function claimNFT(address recipient) external onlyOwner {
    positionManager.safeTransferFrom(address(this), recipient, tokenId);
  }

  function collectFees()
    external
    onlyOwner
    returns (
      address tokenCollected0,
      address tokenCollected1,
      uint256 collectedFees0,
      uint256 collectedFees1
    )
  {
    address recipient = msg.sender;
    tokenCollected0 = pool.token0();
    tokenCollected1 = pool.token1();

    (uint256 feeAmount0, uint256 feeAmount1) = Helper.fees(positionManager, tokenId);
    if (feeAmount0.add(feeAmount1) != 0) {
      (collectedFees0, collectedFees1) = _collect(recipient, uint128(feeAmount0), uint128(feeAmount1));
      _feesCollected(recipient, pool.token0(), pool.token1(), collectedFees0, collectedFees1);
    }
  }

  function updateRange(
    address tokenA,
    uint256 lowerLimitA,
    uint256 upperLimitA,
    uint16 slippage
  )
    external
    onlyOwner
    returns (
      uint128 liquidityAdded,
      uint256 amountAdded0,
      uint256 amountAdded1,
      uint256 amountRefunded0,
      uint256 amountRefunded1
    )
  {
    (uint256 collected0, uint256 collected1) = _decreaseLiquidity(
      address(this),
      Helper.positionLiquidity(positionManager, tokenId),
      slippage
    );

    tokenId = 0;

    (lowerTick, upperTick) = Helper.validateAndConvertLimits(pool, tokenA, lowerLimitA, upperLimitA);

    (liquidityAdded, amountAdded0, amountAdded1, amountRefunded0, amountRefunded1) = _addLiquidity(
      msg.sender,
      collected0,
      collected1,
      slippage
    );
  }

  function _addLiquidity(
    address _recipient,
    uint256 _amount0,
    uint256 _amount1,
    uint16 _slippage
  )
    internal
    returns (
      uint128 _liquidityAdded,
      uint256 _amountAdded0,
      uint256 _amountAdded1,
      uint256 _amountRefunded0,
      uint256 _amountRefunded1
    )
  {
    (uint256 amountRatioed0, uint256 amountRatioed1) = Helper.convertToRatio(
      Helper.ConvertRatioParams({
        rangePool: RangePool(address(this)),
        recipient: address(this),
        amount0: _amount0,
        amount1: _amount1,
        slippage: _slippage
      })
    );

    if (tokenId == 0) {
      (tokenId, _liquidityAdded, _amountAdded0, _amountAdded1) = _mint(
        _recipient,
        amountRatioed0,
        amountRatioed1,
        _slippage
      );
    } else {
      (_liquidityAdded, _amountAdded0, _amountAdded1) = _increaseLiquidity(
        _recipient,
        amountRatioed0,
        amountRatioed1,
        _slippage
      );
    }

    _amountRefunded0 = amountRatioed0.sub(_amountAdded0);
    _amountRefunded1 = amountRatioed1.sub(_amountAdded1);

    if (_amountRefunded0 != 0) ERC20(pool.token0()).safeTransfer(_recipient, _amountRefunded0);
    if (_amountRefunded1 != 0) ERC20(pool.token1()).safeTransfer(_recipient, _amountRefunded1);
  }

  function _mint(
    address _account,
    uint256 _amount0,
    uint256 _amount1,
    uint16 _slippage
  )
    internal
    returns (
      uint256 _generatedTokenId,
      uint128 _liquidityAdded,
      uint256 _amountAdded0,
      uint256 _amountAdded1
    )
  {
    INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
      token0: pool.token0(),
      token1: pool.token1(),
      fee: pool.fee(),
      tickLower: lowerTick, //Tick needs to exist (right spacing)
      tickUpper: upperTick, //Tick needs to exist (right spacing)
      amount0Desired: _amount0,
      amount1Desired: _amount1,
      amount0Min: Helper.applySlippageTolerance(false, _amount0, _slippage), // slippage check
      amount1Min: Helper.applySlippageTolerance(false, _amount1, _slippage), // slippage check
      recipient: address(this), // receiver of ERC721
      deadline: block.timestamp
    });

    (_generatedTokenId, _liquidityAdded, _amountAdded0, _amountAdded1) = positionManager.mint(params);

    emit LiquidityIncreased(_account, _amountAdded0, _amountAdded1, _liquidityAdded);
    emit PositionMinted(_account, _generatedTokenId);
  }

  function _increaseLiquidity(
    address _recipient,
    uint256 _amount0,
    uint256 _amount1,
    uint16 _slippage
  )
    internal
    returns (
      uint128 _liquidityIncreased,
      uint256 _amountIncreased0,
      uint256 _amountIncreased1
    )
  {
    INonfungiblePositionManager.IncreaseLiquidityParams memory params = INonfungiblePositionManager
      .IncreaseLiquidityParams({
        tokenId: tokenId,
        amount0Desired: _amount0,
        amount1Desired: _amount1,
        amount0Min: Helper.applySlippageTolerance(false, _amount0, _slippage),
        amount1Min: Helper.applySlippageTolerance(false, _amount1, _slippage),
        deadline: block.timestamp
      });

    (_liquidityIncreased, _amountIncreased0, _amountIncreased1) = positionManager.increaseLiquidity(params);

    emit LiquidityIncreased(_recipient, _amountIncreased0, _amountIncreased1, _liquidityIncreased);
  }

  function _decreaseLiquidity(
    address _recipient,
    uint128 _liquidity,
    uint16 _slippage
  ) internal returns (uint256 _amountRemoved0, uint256 _amountRemoved1) {
    uint128 remainingLiquidity = Helper.positionLiquidity(positionManager, tokenId);

    _liquidity = _liquidity > remainingLiquidity ? remainingLiquidity : _liquidity;

    (uint256 _expectedAmount0, uint256 _expectedAmount1) = Helper.getAmountsForLiquidity(
      Helper.oracleSqrtPricex96(pool, oracleSeconds),
      lowerTick,
      upperTick,
      _liquidity
    );

    INonfungiblePositionManager.DecreaseLiquidityParams memory params = INonfungiblePositionManager
      .DecreaseLiquidityParams({
        tokenId: tokenId,
        liquidity: _liquidity,
        amount0Min: Helper.applySlippageTolerance(false, _expectedAmount0, _slippage),
        amount1Min: Helper.applySlippageTolerance(false, _expectedAmount1, _slippage),
        deadline: block.timestamp
      });

    (_amountRemoved0, _amountRemoved1) = positionManager.decreaseLiquidity(params);

    (uint256 collectedFees0, uint256 collectedFees1) = (_liquidity == remainingLiquidity)
      ? Helper.fees(positionManager, tokenId)
      : (0, 0);

    _collect(_recipient, uint128(_amountRemoved0.add(collectedFees0)), uint128(_amountRemoved1.add(collectedFees1)));

    if (collectedFees0.add(collectedFees1) != 0)
      _feesCollected(_recipient, pool.token0(), pool.token1(), collectedFees0, collectedFees1);

    emit LiquidityDecreased(_recipient, _amountRemoved0, _amountRemoved1);
  }

  function _collect(
    address _recipient,
    uint128 _amount0,
    uint128 _amount1
  ) internal returns (uint256 amountCollected0, uint256 amountCollected1) {
    INonfungiblePositionManager.CollectParams memory params = INonfungiblePositionManager.CollectParams({
      tokenId: tokenId,
      recipient: _recipient,
      amount0Max: _amount0,
      amount1Max: _amount1
    });

    (amountCollected0, amountCollected1) = positionManager.collect(params);
  }

  function _feesCollected(
    address _recipient,
    address _token0,
    address _token1,
    uint256 _amount0,
    uint256 _amount1
  ) internal {
    totalClaimedFees0 = totalClaimedFees0.add(_amount0);
    totalClaimedFees1 = totalClaimedFees1.add(_amount1);
    emit FeesCollected(_recipient, _token0, _token1, _amount0, _amount1);
  }
}
