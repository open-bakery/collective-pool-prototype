// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;

import '@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol';

import './RangePoolFactory.sol';
import './RangePool.sol';
import './LiquidityProviderToken.sol';

contract RangePoolManagerBase is Ownable {
  using SafeERC20 for ERC20;

  constructor(address rangePoolFactory_, address weth_) {
    rangePoolFactory = RangePoolFactory(rangePoolFactory_);
    weth = weth_;
  }

  struct PositionData {
    uint160 liquidity;
    uint256 clearedFees0;
    uint256 clearedFees1;
  }

  RangePoolFactory rangePoolFactory;
  address weth;

  mapping(address => mapping(address => bool)) public isRegistered; // isRegistered[rangePool][strategy] = bool;
  mapping(address => mapping(address => bool)) public isRangePoolAdmin; // Is allowed to attach strategies to pools.
  mapping(address => address) public rangePoolOwner; // Owners of private pools
  mapping(address => address) public liquitityToken; // liquidityToken[rangePool] = address;

  mapping(address => mapping(address => PositionData)) public position; // position[rangePool][user] = PositionData;

  modifier onlyAdmin(address rangePool) {
    require(isRangePoolAdmin[rangePool][msg.sender], 'RangePoolManagerBase: Caller not range pool admin');
    _;
  }

  event PrivateRangePoolCreated(address indexed rangePool, address indexed createdBy);

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
    rangePoolOwner[rangePool] = msg.sender;
    isRangePoolAdmin[rangePool][msg.sender] = true;
    emit PrivateRangePoolCreated(rangePool, msg.sender);
  }

  function createCollectiveRangePool(
    address tokenA,
    address tokenB,
    uint24 fee,
    uint32 oracleSeconds,
    uint256 lowerLimitInTokenB,
    uint256 upperLimitInTokenB
  ) external returns (address rangePool) {}

  function cloneRangePool(bool isPrivate) external returns (address rangePool) {}

  function addLiquidity(
    RangePool rangePool,
    uint256 amount0,
    uint256 amount1,
    uint16 slippage,
    address delegate
  )
    public
    virtual
    returns (
      uint128 liquidityAdded,
      uint256 amountAdded0,
      uint256 amountAdded1,
      uint256 amountRefunded0,
      uint256 amountRefunded1
    )
  {
    bool isPrivate = _checkIfPrivate(address(rangePool), msg.sender, delegate);

    address token0 = rangePool.pool().token0();
    address token1 = rangePool.pool().token1();

    ERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);
    ERC20(token1).safeTransferFrom(msg.sender, address(this), amount1);

    (amount0, amount1) = _checkEthDeposit(token0, token1, amount0, amount1);

    ERC20(token0).safeApprove(address(rangePool), amount0);
    ERC20(token1).safeApprove(address(rangePool), amount1);

    (liquidityAdded, amountAdded0, amountAdded1, amountRefunded0, amountRefunded1) = rangePool.addLiquidity(
      amount0,
      amount1,
      slippage
    );

    if (amountRefunded0 + amountRefunded1 != 0) {
      _safeTransferTokens(msg.sender, token0, token1, amountRefunded0, amountRefunded1);
    }

    if (isPrivate) {} else {
      if (liquitityToken[address(rangePool)] == address(0))
        liquitityToken[address(rangePool)] = address(new LiquidityProviderToken(rangePool.tokenId()));

      address lp = liquitityToken[address(rangePool)];
      _mint(address(lp), msg.sender, liquidityAdded);
    }
  }

  function removeLiquidity(
    RangePool rangePool,
    uint128 liquidityAmount,
    uint16 slippage,
    address delegate
  ) public returns (uint256 amountRemoved0, uint256 amountRemoved1) {
    bool isPrivate = _checkIfPrivate(address(rangePool), msg.sender, delegate);

    (amountRemoved0, amountRemoved1) = rangePool.removeLiquidity(liquidityAmount, slippage);

    if (isPrivate) {
      _safeTransferTokens(
        msg.sender,
        rangePool.pool().token0(),
        rangePool.pool().token1(),
        amountRemoved0,
        amountRemoved1
      );
    } else {}
  }

  function collectFees(RangePool rangePool, address delegate)
    public
    returns (
      address tokenCollected0,
      address tokenCollected1,
      uint256 collectedFees0,
      uint256 collectedFees1
    )
  {
    bool isPrivate = _checkIfPrivate(address(rangePool), msg.sender, delegate);

    (tokenCollected0, tokenCollected1, collectedFees0, collectedFees1) = rangePool.collectFees();

    if (isPrivate) {
      _safeTransferTokens(msg.sender, tokenCollected0, tokenCollected1, collectedFees0, collectedFees1);
    } else {}
  }

  function updateRange(
    RangePool rangePool,
    address tokenA,
    uint256 lowerLimitA,
    uint256 upperLimitA,
    uint16 slippage,
    address delegate
  )
    public
    returns (
      uint128 liquidityAdded,
      uint256 amountAdded0,
      uint256 amountAdded1,
      uint256 amountRefunded0,
      uint256 amountRefunded1
    )
  {
    bool isPrivate = _checkIfPrivate(address(rangePool), msg.sender, delegate);

    if (isPrivate) {
      (liquidityAdded, amountAdded0, amountAdded1, amountRefunded0, amountRefunded1) = rangePool.updateRange(
        tokenA,
        lowerLimitA,
        upperLimitA,
        slippage
      );

      if (amountRefunded0 + amountRefunded1 != 0) {
        _safeTransferTokens(
          msg.sender,
          rangePool.pool().token0(),
          rangePool.pool().token1(),
          amountRefunded0,
          amountRefunded1
        );
      }
    } else {}
  }

  function claimNFT(RangePool rangePool, address recipient) external {
    require(
      rangePoolOwner[address(rangePool)] == msg.sender,
      'RangePoolManagerBase: Only private pool owners can claim NFTs'
    );
    rangePool.claimNFT(recipient);
  }

  function attach(address rangePool, address strategy) external onlyAdmin(rangePool) {
    isRegistered[rangePool][strategy] = true;
  }

  function _checkIfPrivate(
    address rangePool,
    address sender,
    address delegate
  ) private view returns (bool isPrivate) {
    address caller = (isRegistered[address(rangePool)][sender]) ? delegate : sender;

    if (rangePoolOwner[rangePool] != address(0)) {
      require(rangePoolOwner[rangePool] == caller, 'RangePoolManagerBase: Range Pool is private');
      isPrivate = true;
    }
  }

  function _safeTransferTokens(
    address _recipient,
    address _token0,
    address _token1,
    uint256 _amount0,
    uint256 _amount1
  ) internal {
    _safeTransferToken(_recipient, _token0, _amount0);
    _safeTransferToken(_recipient, _token1, _amount1);
  }

  function _safeTransferToken(
    address _recipient,
    address _token,
    uint256 _amount
  ) internal {
    if (_amount != 0) ERC20(_token).safeTransfer(_recipient, _min(_amount, ERC20(_token).balanceOf(address(this))));
  }

  function _min(uint256 a, uint256 b) internal pure returns (uint256) {
    return a < b ? a : b;
  }

  function _mint(
    address _lpToken,
    address _recipient,
    uint256 _amount
  ) private {
    LiquidityProviderToken(_lpToken).mint(_recipient, _amount);
  }

  function _checkEthDeposit(
    address _token0,
    address _token1,
    uint256 _amount0,
    uint256 _amount1
  ) internal returns (uint256, uint256) {
    uint256 _ethAmount = msg.value;

    if (_ethAmount != 0) {
      require(_token0 == weth || _token1 == weth, 'RangePoolManager: Eth not supported for this pool.');
      IWETH9(weth).deposit{ value: _ethAmount }();
      (_amount0, _amount1) = (_token0 == weth) ? (_amount0 + _ethAmount, _amount1) : (_amount0, _amount1 + _ethAmount);
    }
    return (_amount0, _amount1);
  }
}
