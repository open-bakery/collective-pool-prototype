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
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';

import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import '@uniswap/v3-periphery/contracts/libraries/PositionValue.sol';
import '@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol';
import '@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol';

import './libraries/RatioCalculator.sol';
import './libraries/Swapper.sol';
import './libraries/Utils.sol';
import './libraries/PoolUtils.sol';
import './libraries/Math.sol';
import './libraries/Lens.sol';
import './LP.sol';

// All prices and ranges in Uniswap are denominated in token1 (y) relative to token0 (x): (y/x as in x*y=k)
//Contract responsible for creating new pools.
contract RangePool is Ownable {
  using PositionValue for INonfungiblePositionManager;
  using PoolUtils for IUniswapV3Pool;
  using Address for address;
  using SafeERC20 for ERC20;
  using RatioCalculator for uint160;
  using SafeMath for uint256;

  IUniswapV3Pool public pool;
  LP public lpToken;

  address public token0;
  address public token1;

  int24 public lowerTick;
  int24 public upperTick;
  int24 public tickSpacing;
  uint24 public fee;
  uint32 public oracleSeconds = 60;

  uint256 public tokenId;
  uint256 public totalClaimedFees0;
  uint256 public totalClaimedFees1;

  event LiquidityIncreased(address indexed recipient, uint256 amount0, uint256 amount1, uint128 liquidity);
  event LiquidityDecreased(address indexed recipient, uint256 amount0, uint256 amount1, uint128 liquidity);
  event FeesCollected(address indexed recipient, uint256 amountCollected0, uint256 amountCollected1);
  event DCA(address indexed recipient, uint256 amount);

  constructor(
    address _tokenA,
    address _tokenB,
    uint24 _fee,
    uint256 _lowerLimitInTokenB,
    uint256 _upperLimitInTokenB
  ) {
    pool = IUniswapV3Pool(Utils.getPoolAddress(_tokenA, _tokenB, _fee, Lens.uniswapFactory));
    (token0, token1) = Utils.orderTokens(_tokenA, _tokenB);

    ERC20(token0).safeApprove(address(Lens.NFPM), type(uint256).max);
    ERC20(token1).safeApprove(address(Lens.NFPM), type(uint256).max);

    fee = _fee;
    tickSpacing = pool.tickSpacing();
    (lowerTick, upperTick) = Utils.validateAndConvertLimits(pool, _tokenB, _lowerLimitInTokenB, _upperLimitInTokenB);
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
      uint256 amountAdded1
    )
  {
    ERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);
    ERC20(token1).safeTransferFrom(msg.sender, address(this), amount1);
    (liquidityAdded, amountAdded0, amountAdded1) = _addLiquidity(msg.sender, amount0, amount1, slippage);
  }

  function decreaseLiquidity(uint128 liquidity, uint16 slippage)
    external
    onlyOwner
    returns (uint256 amountDecreased0, uint256 amountDecreased1)
  {
    if (uint256(liquidity) == ERC20(lpToken).balanceOf(msg.sender)) {
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
    LP(lpToken).burn(msg.sender, LP(lpToken).balanceOf(msg.sender));
    Lens.NFPM.safeTransferFrom(address(this), msg.sender, tokenId);
  }

  function collectFees() external onlyOwner returns (uint256 amountCollected0, uint256 amountCollected1) {
    (amountCollected0, amountCollected1) = _collectFees(msg.sender);
  }

  function compound(uint16 slippage)
    external
    onlyOwner
    returns (
      uint128 addedLiquidity,
      uint256 amountCompounded0,
      uint256 amountCompounded1
    )
  {
    (addedLiquidity, amountCompounded0, amountCompounded1) = _compound(msg.sender, slippage);
  }

  function dca(address wantToken, uint16 slippage) public returns (uint256) {
    return _dcaSimple(msg.sender, wantToken, slippage);
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
    (lowerTick, upperTick) = Utils.validateAndConvertLimits(pool, tokenA, lowerLimitA, upperLimitA);
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
    (uint256 amountRatioed0, uint256 amountRatioed1) = _convertToRatio(address(this), _amount0, _amount1, _slippage);

    if (tokenId == 0) {
      (tokenId, _liquidityAdded, _amountAdded0, _amountAdded1) = _mint(
        _recipient,
        amountRatioed0,
        amountRatioed1,
        _slippage
      );

      uint256 refund0 = amountRatioed0.sub(_amountAdded0);
      uint256 refund1 = amountRatioed1.sub(_amountAdded1);
      if (refund0 != 0) ERC20(token0).safeTransfer(_recipient, refund0);
      if (refund1 != 0) ERC20(token1).safeTransfer(_recipient, refund1);
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
    uint256 amountMinAccepted0 = Utils.applySlippageTolerance(false, _amount0, _slippage, Lens.resolution);
    uint256 amountMinAccepted1 = Utils.applySlippageTolerance(false, _amount1, _slippage, Lens.resolution);

    INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
      token0: token0,
      token1: token1,
      fee: fee,
      tickLower: lowerTick, //Tick needs to exist (right spacing)
      tickUpper: upperTick, //Tick needs to exist (right spacing)
      amount0Desired: _amount0,
      amount1Desired: _amount1,
      amount0Min: amountMinAccepted0, // slippage check
      amount1Min: amountMinAccepted1, // slippage check
      recipient: address(this), // receiver of ERC721
      deadline: block.timestamp
    });

    (_generatedTokenId, _liquidityAdded, _amountAdded0, _amountAdded1) = Lens.NFPM.mint(params);

    if (address(lpToken) == address(0)) lpToken = new LP(_generatedTokenId);
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
    uint256 amountMinAccepted0 = Utils.applySlippageTolerance(false, _amount0, _slippage, Lens.resolution);
    uint256 amountMinAccepted1 = Utils.applySlippageTolerance(false, _amount1, _slippage, Lens.resolution);

    INonfungiblePositionManager.IncreaseLiquidityParams memory params = INonfungiblePositionManager
      .IncreaseLiquidityParams({
        tokenId: tokenId,
        amount0Desired: _amount0,
        amount1Desired: _amount1,
        amount0Min: amountMinAccepted0,
        amount1Min: amountMinAccepted1,
        deadline: block.timestamp
      });

    (_liquidityIncreased, _amountIncreased0, _amountIncreased1) = Lens.NFPM.increaseLiquidity(params);

    lpToken.mint(_recipient, uint256(_liquidityIncreased));
    emit LiquidityIncreased(_recipient, _amountIncreased0, _amountIncreased1, _liquidityIncreased);
  }

  function _decreaseLiquidity(
    address _account,
    uint128 _liquidity,
    uint16 _slippage
  ) internal returns (uint256 _amountDecreased0, uint256 _amountDecreased1) {
    require(lpToken.balanceOf(_account) >= _liquidity, 'RangePool: Not enough liquidity');

    (uint256 _expectedAmount0, uint256 _expectedAmount1) = LiquidityAmounts.getAmountsForLiquidity(
      pool.oracleSqrtPricex96(oracleSeconds),
      TickMath.getSqrtRatioAtTick(lowerTick),
      TickMath.getSqrtRatioAtTick(upperTick),
      _liquidity
    );

    uint256 amountMin0 = Utils.applySlippageTolerance(false, _expectedAmount0, _slippage, Lens.resolution);
    uint256 amountMin1 = Utils.applySlippageTolerance(false, _expectedAmount1, _slippage, Lens.resolution);

    INonfungiblePositionManager.DecreaseLiquidityParams memory params = INonfungiblePositionManager
      .DecreaseLiquidityParams({
        tokenId: tokenId,
        liquidity: _liquidity,
        amount0Min: amountMin0,
        amount1Min: amountMin1,
        deadline: block.timestamp
      });

    lpToken.burn(_account, uint256(_liquidity));
    (_amountDecreased0, _amountDecreased1) = Lens.NFPM.decreaseLiquidity(params);
  }

  function _removeLiquidity(
    address _deductAccount,
    address _recipient,
    uint16 _slippage
  ) internal returns (uint256 totalRemoved0, uint256 totalRemoved1) {
    (uint256 amountRemoved0, uint256 amountRemoved1) = _decreaseLiquidity(
      _deductAccount,
      uint128(ERC20(lpToken).balanceOf(msg.sender)),
      _slippage
    );

    (uint256 feeAmount0, uint256 feeAmount1) = Lens.NFPM.fees(tokenId);

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

    (amountCollected0, amountCollected1) = Lens.NFPM.collect(params);
  }

  function _collectFees(address _recipient) internal returns (uint256 amountCollected0, uint256 amountCollected1) {
    (uint256 feeAmount0, uint256 feeAmount1) = Lens.NFPM.fees(tokenId);
    if (feeAmount0.add(feeAmount1) == 0) return (amountCollected0, amountCollected1);

    (amountCollected0, amountCollected1) = _collect(_recipient, uint128(feeAmount0), uint128(feeAmount1));
    totalClaimedFees0 = totalClaimedFees0.add(amountCollected0);
    totalClaimedFees1 = totalClaimedFees1.add(amountCollected1);

    emit FeesCollected(_recipient, amountCollected0, amountCollected1);
  }

  function _compound(address _recipient, uint16 _slippage)
    internal
    returns (
      uint128 _addedLiquidity,
      uint256 _amountCompounded0,
      uint256 _amountCompounded1
    )
  {
    (uint256 amountCollected0, uint256 amountCollected1) = _collectFees(address(this));
    (_addedLiquidity, _amountCompounded0, _amountCompounded1) = _addLiquidity(
      _recipient,
      amountCollected0,
      amountCollected1,
      _slippage
    );
  }

  function _dcaSimple(
    address _recipient,
    address _wantToken,
    uint16 _slippage
  ) internal returns (uint256 amountSent) {
    require(
      _wantToken == token0 || _wantToken == token1,
      'RangePool: Can only DCA into a token belonging to this pool'
    );

    (uint256 amountCollected0, uint256 amountCollected1) = _collectFees(address(this));

    (address tokenIn, address tokenOut) = (_wantToken == token0) ? (token1, token0) : (token0, token1);
    (uint256 amountIn, uint256 amountCollected) = (tokenIn == token0)
      ? (amountCollected0, amountCollected1)
      : (amountCollected1, amountCollected0);

    uint256 amountAcquired = Swapper.swap(
      address(this),
      tokenIn,
      tokenOut,
      fee,
      amountIn,
      _slippage,
      oracleSeconds,
      Lens.resolution
    );

    uint256 totalAmount = amountAcquired.add(amountCollected);

    amountSent = Utils.safeBalanceTransfer(_wantToken, address(this), _recipient, totalAmount);

    emit DCA(_recipient, amountSent);
  }

  function _convertToRatio(
    address _recipient,
    uint256 _amount0,
    uint256 _amount1,
    uint16 _slippage
  ) internal returns (uint256 amount0, uint256 amount1) {
    (uint256 targetAmount0, uint256 targetAmount1) = pool.sqrtPriceX96().calculateRatio(
      pool.liquidity(),
      _amount0,
      _amount1,
      lowerTick,
      upperTick,
      ERC20(token0).decimals(),
      Lens.resolution
    );

    amount0 = _amount0;
    amount1 = _amount1;
    uint256 diff;

    if (_amount0 > targetAmount0) {
      diff = _amount0.sub(targetAmount0);
      amount0 = amount0.sub(diff);
      amount1 = amount1.add(
        Swapper.swap(_recipient, token0, token1, fee, diff, _slippage, oracleSeconds, Lens.resolution)
      );
    }

    if (_amount1 > targetAmount1) {
      diff = _amount1.sub(targetAmount1);
      amount1 = amount1.sub(diff);
      amount0 = amount0.add(
        Swapper.swap(_recipient, token1, token0, fee, diff, _slippage, oracleSeconds, Lens.resolution)
      );
    }

    assert(ERC20(token0).balanceOf(address(this)) >= amount0);
    assert(ERC20(token1).balanceOf(address(this)) >= amount1);
  }
}
