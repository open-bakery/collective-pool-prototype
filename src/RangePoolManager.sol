// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;

import '@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol';

import './RangePoolFactory.sol';
import './RangePool.sol';
import './LiquidityProviderToken.sol';

contract RangePoolManager is Ownable {
  using SafeERC20 for ERC20;

  struct PositionData {
    uint160 liquidity;
    uint256 clearedFees0;
    uint256 clearedFees1;
  }

  RangePoolFactory rangePoolFactory;

  address weth;

  mapping(address => bool) public isRegistered; // isRegistered[rangePool][strategy] = bool;
  mapping(address => address) public poolController;
  mapping(address => address) public liquitityToken; // liquidityToken[rangePool] = address;
  mapping(address => mapping(address => PositionData)) public position; // position[rangePool][user] = PositionData;

  modifier onlyAllowed() {
    require(msg.sender == owner() || isRegistered[msg.sender] == true, 'RangePoolManager: Caller not allowed');
    _;
  }

  event PrivateRangePoolCreated(address indexed rangePool);

  constructor(address rangePoolFactory_) {
    rangePoolFactory = RangePoolFactory(rangePoolFactory_);
  }

  function setWeth(address _weth) external onlyOwner {
    require(_weth == address(0), 'RangePoolManager: Weth already set');
    weth = _weth;
  }

  function createPrivateRangePool(
    address tokenA,
    address tokenB,
    uint24 fee,
    uint32 oracleSeconds,
    uint256 lowerLimitInTokenB,
    uint256 upperLimitInTokenB
  ) external returns (address rangePool) {
    rangePool = rangePoolFactory.deployRangePool(
      tokenA,
      tokenB,
      fee,
      oracleSeconds,
      lowerLimitInTokenB,
      upperLimitInTokenB
    );
    poolController[rangePool] = msg.sender;
    emit PrivateRangePoolCreated(rangePool);
  }

  function createCollectiveRangePool(
    address tokenA,
    address tokenB,
    uint24 fee,
    uint32 oracleSeconds,
    uint256 lowerLimitInTokenB,
    uint256 upperLimitInTokenB
  ) external returns (address rangePool) {
    //rangePool = rangePoolFactory.deployRangePool(
    //     tokenA,
    //     tokenB,
    //     fee,
    //     oracleSeconds,
    //     lowerLimitInTokenB,
    //     upperLimitInTokenB
    //   );
    //   emit PrivateRangePoolCreated(rangePool);
  }

  function cloneRangePool(bool isPrivate) external returns (address rangePool) {}

  function addLiquidity(
    address rangePool,
    uint256 amount0,
    uint256 amount1,
    uint16 slippage
  )
    external
    payable
    returns (
      uint128 liquidityAdded,
      uint256 amountAdded0,
      uint256 amountAdded1,
      uint256 amountRefunded0,
      uint256 amountRefunded1
    )
  {
    bool isPrivate = _checkIfPrivate(rangePool, msg.sender);
    address token0 = RangePool(rangePool).pool().token0();
    address token1 = RangePool(rangePool).pool().token1();

    ERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);
    ERC20(token1).safeTransferFrom(msg.sender, address(this), amount1);

    ERC20(token0).safeApprove(rangePool, amount0);
    ERC20(token1).safeApprove(rangePool, amount1);

    (liquidityAdded, amountAdded0, amountAdded1, amountRefunded0, amountRefunded1) = RangePool(rangePool).addLiquidity(
      amount0,
      amount1,
      slippage
    );

    if (amountRefunded0 + amountRefunded1 != 0) {
      _refundTokens(msg.sender, token0, token1, amountRefunded0, amountRefunded1);
    }

    if (!isPrivate) {
      // Code for collective pools
      // PositionData memory cachePosition;
      if (liquitityToken[rangePool] == address(0))
        liquitityToken[rangePool] = address(new LiquidityProviderToken(RangePool(rangePool).tokenId()));

      address lp = liquitityToken[rangePool];
      _mint(address(lp), msg.sender, liquidityAdded);
    }
  }

  function removeLiquidity(
    address rangePool,
    uint128 liquidityAmount,
    uint16 slippage
  ) external returns (uint256 amountRemoved0, uint256 amountRemoved1) {
    bool isPrivate = _checkIfPrivate(rangePool, msg.sender);

    (amountRemoved0, amountRemoved1) = RangePool(rangePool).removeLiquidity(liquidityAmount, slippage);

    if (!isPrivate) {
      // Code for collective pools
    }

    _safeTransferTokens(
      msg.sender,
      RangePool(rangePool).pool().token0(),
      RangePool(rangePool).pool().token1(),
      amountRemoved0,
      amountRemoved1
    );
  }

  function claimNFT(address rangePool, address recipient) external {
    require(poolController[rangePool] == msg.sender, 'RangePoolManager: Only private pool owners can claim NFTs');
    RangePool(rangePool).claimNFT(recipient);
  }

  function collectFees(address rangePool)
    external
    returns (
      address tokenCollected0,
      address tokenCollected1,
      uint256 collectedFees0,
      uint256 collectedFees1
    )
  {
    bool isPrivate = _checkIfPrivate(rangePool, msg.sender);

    (tokenCollected0, tokenCollected1, collectedFees0, collectedFees1) = RangePool(rangePool).collectFees();

    if (!isPrivate) {
      // Code for collective pools
    }

    _safeTransferTokens(msg.sender, tokenCollected0, tokenCollected1, collectedFees0, collectedFees1);
  }

  function updateRange(
    address rangePool,
    address tokenA,
    uint256 lowerLimitA,
    uint256 upperLimitA,
    uint16 slippage
  )
    external
    returns (
      uint128 liquidityAdded,
      uint256 amountAdded0,
      uint256 amountAdded1,
      uint256 amountRefunded0,
      uint256 amountRefunded1
    )
  {
    bool isPrivate = _checkIfPrivate(rangePool, msg.sender);

    (liquidityAdded, amountAdded0, amountAdded1, amountRefunded0, amountRefunded1) = RangePool(rangePool).updateRange(
      tokenA,
      lowerLimitA,
      upperLimitA,
      slippage
    );

    if (!isPrivate) {
      // Code for collective pools
    }

    _safeTransferTokens(
      msg.sender,
      RangePool(rangePool).pool().token0(),
      RangePool(rangePool).pool().token1(),
      amountRefunded0,
      amountRefunded1
    );
  }

  function _safeTransferTokens(
    address _recipient,
    address _token0,
    address _token1,
    uint256 _amount0,
    uint256 _amount1
  ) internal {
    ERC20(_token0).safeTransfer(msg.sender, _min(_amount0, ERC20(_token0).balanceOf(address(this))));
    ERC20(_token1).safeTransfer(msg.sender, _min(_amount1, ERC20(_token1).balanceOf(address(this))));
  }

  function _min(uint256 a, uint256 b) internal pure returns (uint256) {
    return a < b ? a : b;
  }

  function _refundTokens(
    address _recipient,
    address _token0,
    address _token1,
    uint256 _amount0,
    uint256 _amount1
  ) private {
    if (_amount0 != 0) ERC20(_token0).safeTransfer(_recipient, _amount0);
    if (_amount1 != 0) ERC20(_token1).safeTransfer(_recipient, _amount1);
  }

  function _checkIfPrivate(address rangePool, address caller) private view returns (bool isPrivate) {
    if (poolController[rangePool] != address(0)) {
      require(poolController[rangePool] == caller, 'RangePoolManager: Range Pool is private');
      isPrivate = true;
    }
  }

  function _mint(
    address _lpToken,
    address _recipient,
    uint256 _amount
  ) private {
    LiquidityProviderToken(_lpToken).mint(_recipient, _amount);
  }

  // function _useWeth(uint256 token0Amount, uint256 token1Amount)
  //   internal
  //   returns (
  //     uint256,
  //     uint256,
  //     bool
  //   )
  // {
  //   bool _ethUsed = false;
  //   uint256 _eth = msg.value;
  //   if (_eth > 0) {
  //     IWETH9(weth).deposit{ value: _eth }();
  //
  //     if (pool.token0() == weth) {
  //       token0Amount = _eth;
  //       _ethUsed = true;
  //     } else if (pool.token1() == weth) {
  //       token1Amount = _eth;
  //       _ethUsed = true;
  //     }
  //   }
  //   return (token0Amount, token1Amount, _ethUsed);
  // }
}
