// SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.20;

interface IAccessControl {
    error PegManagerAddressZero();
    error UnauthorizedAccount(address sender);
}
