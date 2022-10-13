// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;

import 'forge-std/Test.sol';

contract Logs is Test {
  function logr(
    string memory header,
    string[6] memory params,
    uint256[6] memory nums
  ) external view {
    string memory printParam;
    _limit();
    console.log(header);
    for (uint8 i = 0; i < params.length; i++) {
      if (keccak256(abi.encodePacked((params[i]))) != keccak256(abi.encodePacked(('0')))) {
        printParam = string(abi.encodePacked(params[i], ': '));
        console.log(printParam, nums[i]);
      }
    }
    _limit();
  }

  function _limit() private view {
    console.log('--------------------------');
  }
}
