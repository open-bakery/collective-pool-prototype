// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import '@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol';

import './libraries/Helper.sol';

import './RangePoolFactory.sol';
import './LiquidityProviderToken.sol';

// All prices and ranges in Uniswap are denominated in token1 (y) relative to token0 (x): (y/x as in x*y=k)
//Contract responsible for creating new pools.
contract RangePool is Ownable {
  using SafeERC20 for ERC20;
  using Address for address;
  using SafeMath for uint256;

  RangePoolFactory public rangePoolFactory;
  IUniswapV3Pool public pool;
  LiquidityProviderToken public lpToken;

  int24 public lowerTick;
  int24 public upperTick;
  uint32 public oracleSeconds = 60;

  uint256 public tokenId;
  uint256 public totalClaimedFees0;
  uint256 public totalClaimedFees1;

  mapping(address => bool) public isRegistered;

  event LiquidityIncreased(address indexed recipient, uint256 amount0, uint256 amount1, uint128 liquidity);
  event LiquidityDecreased(address indexed recipient, uint256 amount0, uint256 amount1, uint128 liquidity);
  event FeesCollected(address indexed recipient, uint256 amountCollected0, uint256 amountCollected1);
  event DCA(address indexed recipient, uint256 amount);

  modifier onlyAllowed() {
    require(msg.sender == owner() || isRegistered[msg.sender] == true, 'RangePool:NA'); // Caller not alloed
    _;
  }

  constructor(
    address _tokenA,
    address _tokenB,
    uint24 _fee,
    uint256 _lowerLimitInTokenB,
    uint256 _upperLimitInTokenB
  ) {
    rangePoolFactory = RangePoolFactory(msg.sender);
    pool = IUniswapV3Pool(Helper.getPoolAddress(_tokenA, _tokenB, _fee, address(rangePoolFactory.uniFactory())));

    (lowerTick, upperTick) = Helper.validateAndConvertLimits(pool, _tokenB, _lowerLimitInTokenB, _upperLimitInTokenB);

    ERC20(pool.token0()).safeApprove(address(rangePoolFactory.positionManager()), type(uint256).max);
    ERC20(pool.token1()).safeApprove(address(rangePoolFactory.positionManager()), type(uint256).max);
  }

  function toggleStrategy(address strategy) external onlyOwner {
    isRegistered[strategy] = !isRegistered[strategy];
  }

  function addLiquidity(
    uint256 amount0,
    uint256 amount1,
    uint16 slippage
  )
    external
    payable
    onlyAllowed
    returns (
      uint128 liquidityAdded,
      uint256 amountAdded0,
      uint256 amountAdded1
    )
  {
    ERC20(pool.token0()).safeTransferFrom(msg.sender, address(this), amount0);
    ERC20(pool.token1()).safeTransferFrom(msg.sender, address(this), amount1);
    (liquidityAdded, amountAdded0, amountAdded1) = _addLiquidity(msg.sender, amount0, amount1, slippage);
  }

  function decreaseLiquidity(uint128 liquidity, uint16 slippage)
    external
    onlyOwner
    returns (uint256 amountDecreased0, uint256 amountDecreased1)
  {
    if (uint256(liquidity) == lpToken.balanceOf(msg.sender)) {
      (amountDecreased0, amountDecreased1) = _removeLiquidity(msg.sender, msg.sender, slippage);
    } else {
      (amountDecreased0, amountDecreased1) = _decreaseLiquidity(msg.sender, liquidity, slippage);
      _collect(msg.sender, uint128(amountDecreased0), uint128(amountDecreased1));
    }
  }

  function removeLiquidity(uint16 slippage)
    external
    onlyOwner
    returns (uint256 amountRemoved0, uint256 amountRemoved1)
  {
    (amountRemoved0, amountRemoved1) = _removeLiquidity(msg.sender, msg.sender, slippage);
  }

  function claimNFT() external onlyOwner {
    lpToken.burn(msg.sender, lpToken.balanceOf(msg.sender));
    rangePoolFactory.positionManager().safeTransferFrom(address(this), msg.sender, tokenId);
  }

  function collectFees() external onlyAllowed returns (uint256 amountCollected0, uint256 amountCollected1) {
    (amountCollected0, amountCollected1) = _collectFees(msg.sender);
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
      uint128 addedLiquidity,
      uint256 addedAmount0,
      uint256 addedAmount1
    )
  {
    (lowerTick, upperTick) = Helper.validateAndConvertLimits(pool, tokenA, lowerLimitA, upperLimitA);
    (uint256 collected0, uint256 collected1) = _removeLiquidity(msg.sender, address(this), slippage);
    tokenId = 0;
    (addedLiquidity, addedAmount0, addedAmount1) = _addLiquidity(msg.sender, collected0, collected1, slippage);
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
      uint256 _amountAdded1
    )
  {
    (uint256 amountRatioed0, uint256 amountRatioed1) = Helper.convertToRatio(
      Helper.ConvertRatioParams({
        rangePool: RangePool(address(this)),
        recipient: address(this),
        amount0: _amount0,
        amount1: _amount1,
        slippage: _slippage
      }),
      address(rangePoolFactory.uniFactory()),
      address(rangePoolFactory.router())
    );

    if (tokenId == 0) {
      (tokenId, _liquidityAdded, _amountAdded0, _amountAdded1) = _mint(
        _recipient,
        amountRatioed0,
        amountRatioed1,
        _slippage
      );

      uint256 refund0 = amountRatioed0.sub(_amountAdded0);
      uint256 refund1 = amountRatioed1.sub(_amountAdded1);
      if (refund0 != 0) ERC20(pool.token0()).safeTransfer(_recipient, refund0);
      if (refund1 != 0) ERC20(pool.token1()).safeTransfer(_recipient, refund1);
    } else {
      (_liquidityAdded, _amountAdded0, _amountAdded1) = _increaseLiquidity(
        _recipient,
        amountRatioed0,
        amountRatioed1,
        _slippage
      );
    }
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

    (_generatedTokenId, _liquidityAdded, _amountAdded0, _amountAdded1) = rangePoolFactory.positionManager().mint(
      params
    );

    if (address(lpToken) == address(0)) lpToken = new LiquidityProviderToken(_generatedTokenId);
    lpToken.mint(_account, _liquidityAdded);
    emit LiquidityIncreased(_account, _amountAdded0, _amountAdded1, _liquidityAdded);
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

    (_liquidityIncreased, _amountIncreased0, _amountIncreased1) = rangePoolFactory.positionManager().increaseLiquidity(
      params
    );

    lpToken.mint(_recipient, uint256(_liquidityIncreased));
    emit LiquidityIncreased(_recipient, _amountIncreased0, _amountIncreased1, _liquidityIncreased);
  }

  function _decreaseLiquidity(
    address _account,
    uint128 _liquidity,
    uint16 _slippage
  ) internal returns (uint256 _amountDecreased0, uint256 _amountDecreased1) {
    require(lpToken.balanceOf(_account) >= _liquidity, 'RangePool: Not enough liquidity');

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

    lpToken.burn(_account, uint256(_liquidity));

    (_amountDecreased0, _amountDecreased1) = rangePoolFactory.positionManager().decreaseLiquidity(params);
  }

  function _removeLiquidity(
    address _deductAccount,
    address _recipient,
    uint16 _slippage
  ) internal returns (uint256 totalRemoved0, uint256 totalRemoved1) {
    (uint256 amountRemoved0, uint256 amountRemoved1) = _decreaseLiquidity(
      _deductAccount,
      uint128(lpToken.balanceOf(msg.sender)),
      _slippage
    );

    (uint256 feeAmount0, uint256 feeAmount1) = Helper.fees(rangePoolFactory.positionManager(), tokenId);

    totalClaimedFees0 = totalClaimedFees0.add(feeAmount0);
    totalClaimedFees1 = totalClaimedFees1.add(feeAmount1);

    (totalRemoved0, totalRemoved1) = _collect(
      _recipient,
      uint128(amountRemoved0.add(feeAmount0)),
      uint128(amountRemoved1.add(feeAmount1))
    );

    emit FeesCollected(_recipient, feeAmount0, feeAmount1);
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

    (amountCollected0, amountCollected1) = rangePoolFactory.positionManager().collect(params);
  }

  function _collectFees(address _recipient) internal returns (uint256 amountCollected0, uint256 amountCollected1) {
    (uint256 feeAmount0, uint256 feeAmount1) = Helper.fees(rangePoolFactory.positionManager(), tokenId);
    if (feeAmount0.add(feeAmount1) == 0) return (amountCollected0, amountCollected1);

    (amountCollected0, amountCollected1) = _collect(_recipient, uint128(feeAmount0), uint128(feeAmount1));
    totalClaimedFees0 = totalClaimedFees0.add(amountCollected0);
    totalClaimedFees1 = totalClaimedFees1.add(amountCollected1);

    emit FeesCollected(_recipient, amountCollected0, amountCollected1);
  }

  function _convertEth(uint256 token0Amount, uint256 token1Amount)
    internal
    returns (
      uint256,
      uint256,
      bool
    )
  {
    bool _ethUsed = false;
    uint256 _eth = msg.value;
    address weth = rangePoolFactory.WETH();
    if (_eth > 0) {
      IWETH9(weth).deposit{ value: _eth }();

      if (pool.token0() == weth) {
        token0Amount = _eth;
        _ethUsed = true;
      } else if (pool.token1() == weth) {
        token1Amount = _eth;
        _ethUsed = true;
      }
    }
    return (token0Amount, token1Amount, _ethUsed);
  }
}
