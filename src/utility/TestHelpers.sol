// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.14;
pragma abicoder v2;

import './DeployHelpers.sol';
import '../logs/Logs.sol';
import '../libraries/Helper.sol';

abstract contract TestHelpers is DeployHelpers, Logs {
  function deployBase() public {
    rangePoolFactory = new RangePoolFactory(address(uniswapFactory), address(uniswapRouter), address(positionManager));
    simpleStrategies = new SimpleStrategies();
  }

  function simpleAmount(uint256 amount, address token) internal view returns (uint256) {
    return amount * (10**ERC20(token).decimals());
  }

  function performSwaps(
    address tokenA,
    uint256 amountA,
    address tokenB,
    uint24 fee,
    uint8 swaps
  ) internal {
    ERC20(tokenA).approve(address(uniswapRouter), type(uint256).max);
    ERC20(tokenB).approve(address(uniswapRouter), type(uint256).max);
    deal(address(tokenA), address(this), amountA);
    uint256 receivedA;
    uint256 receivedB;

    receivedB = swap(tokenA, tokenB, fee, amountA);
    uint256 interval = 60 seconds;
    for (uint8 i = 0; i < swaps; i++) {
      skip(interval);
      receivedA = swap(tokenB, tokenA, fee, receivedB);
      receivedB = swap(tokenA, tokenB, fee, receivedA);
    }
  }

  function isCloseTo(
    uint256 value,
    uint256 expected,
    uint256 delta
  ) internal pure returns (bool) {
    uint256 upperLimit = value + delta;
    uint256 lowerLimit = value - delta;
    return (expected <= upperLimit && expected >= lowerLimit);
  }

  function predictAddress(
    string memory salt,
    address _deployer,
    address _tokenA,
    address _tokenB,
    uint24 _fee,
    uint256 _lowerLimitInTokenB,
    uint256 _upperLimitInTokenB
  ) internal pure returns (address) {
    address predictedAddress = address(
      uint160(
        uint256(
          keccak256(
            abi.encodePacked(
              bytes1(0xff),
              address(_deployer),
              keccak256(abi.encode(salt)),
              keccak256(
                abi.encodePacked(
                  type(RangePool).creationCode,
                  abi.encode(_tokenA, _tokenB, _fee, _lowerLimitInTokenB, _upperLimitInTokenB)
                )
              )
            )
          )
        )
      )
    );
    return predictedAddress;
  }

  // function onERC721Received(
  //   address operator,
  //   address from,
  //   uint256 id,
  //   bytes calldata data
  // ) external view override returns (bytes4) {
  //   operator;
  //   from;
  //   id;
  //   data;
  //
  //   logr('onERC721Received()', ['0', '0', '0', '0', '0', '0'], [uint256(0), 0, 0, 0, 0, 0]);
  //
  //   return this.onERC721Received.selector;
  // }
}
