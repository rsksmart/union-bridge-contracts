// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OperatorTakeManager} from "src/OperatorTakeManager.sol";
import {TakeTimeout} from "src/interfaces/IOperatorTakeManager.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {IBitcoinManager} from "src/interfaces/IBitcoinManager.sol";
import {IRbtcBridge} from "src/interfaces/IRbtcBridge.sol";
import {IPegoutManager} from "src/interfaces/IPegoutManager.sol";
import {IStreamManager} from "src/interfaces/IStreamManager.sol";
import {ISignatureManager} from "src/interfaces/ISignatureManager.sol";

/// @title OperatorTakeManagerHarness
/// @notice Test harness for OperatorTakeManager to expose internal state for testing
contract OperatorTakeManagerHarness is OperatorTakeManager {
    function initialize(
        address _initialOwner,
        address _accessManager,
        ICommitteeRegistry _committeeRegistry,
        IBitcoinManager _bitcoinManager,
        IRbtcBridge _rbtcBridge,
        IPegoutManager _pegoutManager,
        IStreamManager _streamManager,
        ISignatureManager _signatureManager,
        TakeTimeout[] memory _takeTimeouts
    ) public override initializer {
        OperatorTakeManager.initialize(
            _initialOwner,
            _accessManager,
            _committeeRegistry,
            _bitcoinManager,
            _rbtcBridge,
            _pegoutManager,
            _streamManager,
            _signatureManager,
            _takeTimeouts
        );
    }

    /// @notice Overrides the stored pegoutId for a given acceptPeginTxid.
    /// @dev Used in BitVMX compatibility tests to inject a known pegoutId so that
    ///      the generated advance funds tx (which has a fixed pegoutId) passes validation.
    function setPegoutIdHarness(bytes32 _acceptPeginTxid, bytes32 _pegoutId) external {
        operatorTakeInfo[_acceptPeginTxid].pegoutId = _pegoutId;
    }
}
