// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;

import '@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol';

import './RangePoolFactory.sol';
import './RangePool.sol';
import './LiquidityProviderToken.sol';

contract RangePoolManagerBase is Ownable {
  using SafeERC20 for ERC20;

  struct RangePoolData {
    address owner;
    address lp;
    mapping(address => bool) isRegisteredStrategy;
  }

  constructor(address rangePoolFactory_, address weth_) {
    rangePoolFactory = RangePoolFactory(rangePoolFactory_);
    weth = weth_;
  }

  RangePoolFactory public rangePoolFactory;
  address public weth;

  mapping(address => RangePoolData) public rangePoolInfo;

  modifier onlyRangePoolOwner(address rangePool) {
    require(rangePoolOwner(rangePool) == msg.sender, 'RangePoolManagerBase: Caller not range pool owner');
    _;
  }

  event PrivateRangePoolCreated(address indexed rangePool, address indexed createdBy);
  event CollectiveRangePoolCreated(address indexed rangePool, address indexed createdBy);
  event StrategyAttached(address indexed rangePool, address indexed strategy, address creator);

  function rangePoolOwner(address rangePool) public view returns (address) {
    return rangePoolInfo[rangePool].owner;
  }

  function rangePoolLP(address rangePool) public view returns (LiquidityProviderToken) {
    return LiquidityProviderToken(rangePoolInfo[rangePool].lp);
  }

  function isRegistered(address rangePool, address strategy) public view returns (bool) {
    return rangePoolInfo[rangePool].isRegisteredStrategy[strategy];
  }

  function isPrivate(address rangePool) public view returns (bool) {
    return (rangePoolOwner(rangePool) != address(0));
  }

  function createPrivateRangePool(
    address tokenA,
    address tokenB,
    uint24 fee,
    uint32 oracleSeconds,
    uint256 lowerLimitInTokenB,
    uint256 upperLimitInTokenB
  ) public returns (address rangePool) {
    rangePool = rangePoolFactory.deployRangePool(
      tokenA,
      tokenB,
      fee,
      oracleSeconds,
      lowerLimitInTokenB,
      upperLimitInTokenB
    );

    _initiateRangePoolData(rangePool, msg.sender, address(0));
    emit PrivateRangePoolCreated(rangePool, msg.sender);
  }

  function createCollectiveRangePool(
    address tokenA,
    address tokenB,
    uint24 fee,
    uint32 oracleSeconds,
    uint256 lowerLimitInTokenB,
    uint256 upperLimitInTokenB,
    address strategy
  ) public returns (address rangePool) {
    rangePool = rangePoolFactory.deployRangePool(
      tokenA,
      tokenB,
      fee,
      oracleSeconds,
      lowerLimitInTokenB,
      upperLimitInTokenB
    );

    require(strategy != address(0), 'RangePoolManagerBase: Collective pools must have strategies');
    _initiateRangePoolData(rangePool, address(0), strategy);

    emit CollectiveRangePoolCreated(rangePool, msg.sender);
  }

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
    _authenticatePrivatePoolAccess(address(rangePool), msg.sender, delegate);

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

    _mint(address(rangePool), msg.sender, liquidityAdded);

    if (amountRefunded0 + amountRefunded1 != 0) {
      _safeTransferTokens(msg.sender, token0, token1, amountRefunded0, amountRefunded1);
    }
  }

  function removeLiquidity(
    RangePool rangePool,
    uint128 liquidityAmount,
    uint16 slippage,
    address delegate
  ) public returns (uint256 amountRemoved0, uint256 amountRemoved1) {
    _authenticatePrivatePoolAccess(address(rangePool), msg.sender, delegate);

    require(
      rangePoolLP(address(rangePool)).balanceOf(msg.sender) >= liquidityAmount,
      'RangePoolManagerBase: Not enough liquidity balance'
    );
    _burn(address(rangePool), msg.sender, liquidityAmount);

    (amountRemoved0, amountRemoved1) = rangePool.removeLiquidity(liquidityAmount, slippage);

    _safeTransferTokens(
      msg.sender,
      rangePool.pool().token0(),
      rangePool.pool().token1(),
      amountRemoved0,
      amountRemoved1
    );
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
    _authenticatePrivatePoolAccess(address(rangePool), msg.sender, delegate);
    _authenticateCollectivePoolAccess(address(rangePool), msg.sender);

    (tokenCollected0, tokenCollected1, collectedFees0, collectedFees1) = rangePool.collectFees();
    _safeTransferTokens(msg.sender, tokenCollected0, tokenCollected1, collectedFees0, collectedFees1);
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
    _authenticatePrivatePoolAccess(address(rangePool), msg.sender, delegate);
    _authenticateCollectivePoolAccess(address(rangePool), msg.sender);

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
  }

  function claimNFT(RangePool rangePool, address recipient) external onlyRangePoolOwner(address(rangePool)) {
    rangePool.claimNFT(recipient);
  }

  function attach(address rangePool, address strategy) external onlyRangePoolOwner(address(rangePool)) {
    RangePoolData storage rdp = rangePoolInfo[rangePool];
    rdp.isRegisteredStrategy[strategy] = true;

    emit StrategyAttached(rangePool, strategy, msg.sender);
  }

  function _initiateRangePoolData(
    address _rangePool,
    address _owner,
    address _strategy
  ) internal {
    RangePoolData storage rpd = rangePoolInfo[_rangePool];
    rpd.owner = _owner;
    rpd.lp = address(new LiquidityProviderToken(RangePool(_rangePool).tokenId()));
    if (_strategy != address(0)) rpd.isRegisteredStrategy[_strategy] = true;
  }

  function _mint(
    address _rangePool,
    address _recipient,
    uint256 _amount
  ) internal {
    rangePoolLP(_rangePool).mint(_recipient, _amount);
  }

  function _burn(
    address _rangePool,
    address _from,
    uint256 _amount
  ) internal {
    rangePoolLP(_rangePool).burn(_from, _amount);
  }

  function _authenticatePrivatePoolAccess(
    address _rangePool,
    address _sender,
    address _delegate
  ) internal view {
    address caller = isRegistered(_rangePool, _sender) ? _delegate : _sender;
    if (isPrivate(_rangePool)) {
      require(rangePoolOwner(_rangePool) == caller, 'RangePoolManagerBase: Caller not allowed in private pool');
    }
  }

  function _authenticateCollectivePoolAccess(address _rangePool, address _sender) internal view {
    if (!isPrivate(_rangePool)) {
      require(isRegistered(_rangePool, _sender), 'RangePoolManagerBase: Caller not allowed in collective pool');
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
