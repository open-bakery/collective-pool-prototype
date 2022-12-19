// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;

import './Compound.sol';
import './Stack.sol';

contract SimpleStrategy is Stack, Compound {}
