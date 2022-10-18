// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';

contract Registry is Ownable {
  mapping(bytes32 => address) regirstry;

  event RegistryUpdated(address indexed extContract, string val, bytes32 key);

  function updateRegistry(string calldata val, address extContract) external onlyOwner {
    bytes32 key = keccak256(abi.encodePacked(val));
    regirstry[key] = extContract;

    emit RegistryUpdated(extContract, val, key);
  }

  function retrieve(string calldata val) external view returns (address) {
    return regirstry[keccak256(abi.encodePacked(val))];
  }
}
