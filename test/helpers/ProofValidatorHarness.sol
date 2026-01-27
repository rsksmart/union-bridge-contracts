// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ProofValidator} from "src/ProofValidator.sol";
import {BaseProxy} from "src/BaseProxy.sol";

/// @title SPVHarness
/// @notice Wrapper for testing ProofValidator
contract ProofValidatorHarness is ProofValidator, BaseProxy {
    function initialize(address _initialOwner, address payable _bridgeAddress, address _pauser) external initializer {
        __BaseProxy_init(_initialOwner);
        __Pauser_init(_pauser);
        __ProofValidator_init(_bridgeAddress, _pauser);
    }

    function verifyTxConfirmationsHarness(
        uint256 _minConfirmations,
        bytes32 _txid,
        bytes32 _blockHash,
        uint256 _merkleBranchPath,
        bytes32[] memory _merkleBranchHashes
    ) external view {
        _verifyTxConfirmations(_minConfirmations, _txid, _blockHash, _merkleBranchPath, _merkleBranchHashes);
    }
}
