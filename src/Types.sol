// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

struct Committee {
    address[2] members;
    bytes32 internalKey;
}
